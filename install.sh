#!/usr/bin/env bash
# ==============================================================================
#  Caelestia Notes - installer
#  STAGE 1: fetch + verify          (default, READ-ONLY - changes nothing)
#  STAGE 2: --install / --uninstall copies the Notes files (backup, verify, rollback)
#  STAGE 3: --install also registers the tab by editing 2 Caelestia files with
#           clearly marked, reversible blocks (backup first; --uninstall removes them)
#
#  Your notes data (~/.local/state/caelestia/notes.json) is never touched.
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/Denzils-repo/Caelestia_Notes/main/install.sh | bash
#    ./install.sh                  check only (safe)
#    ./install.sh --install        check, then install the Notes files
#    ./install.sh --uninstall      remove what --install put there
#    options: --yes (no prompts)  --force (override "shell wins" protection)
#             --no-register (copy files only)  --no-keyboard (skip the typing-focus edit)
#             --repo URL  --branch NAME  --no-color  -h
#
#  Advanced / testing overrides (env): CN_REPO_URL CN_BRANCH CN_USER_DIR
#    CN_SYS_DIR CN_QML_DIRS (colon separated extra QML import dirs)
# ==============================================================================
# shellcheck disable=SC2034
set -uo pipefail

REPO_URL="${CN_REPO_URL:-https://github.com/Denzils-repo/Caelestia_Notes.git}"
BRANCH="${CN_BRANCH:-main}"
CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia-notes"
SRC="$CACHE/repo"

# Shell versions: "tested" = run by the author; MIN = oldest release whose
# Tokens/components/M3Shapes surface was checked against the Notes code.
TESTED_VERSIONS="2.4.0"
MIN_VERSION="2.2.0"

# Exact upstream lines/anchors the later (patching) stages rely on.
KBD_PRISTINE='WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None'

PASS=0; WARNS=0; FAILS=0
USE_COLOR=1; [[ -t 1 && -z "${NO_COLOR:-}" ]] || USE_COLOR=0

c() { (( USE_COLOR )) && printf '\033[%sm' "$1"; }
r() { (( USE_COLOR )) && printf '\033[0m'; }
ok()   { PASS=$((PASS+1));   printf '  %s[ OK ]%s %s\n'  "$(c 32)" "$(r)" "$*"; }
warn() { WARNS=$((WARNS+1)); printf '  %s[WARN]%s %s\n'  "$(c 33)" "$(r)" "$*"; }
bad()  { FAILS=$((FAILS+1)); printf '  %s[FAIL]%s %s\n'  "$(c 31)" "$(r)" "$*"; }
info() { printf '  %s[ .. ]%s %s\n'  "$(c 36)" "$(r)" "$*"; }
step() { printf '\n%s== %s ==%s\n' "$(c '1;35')" "$*" "$(r)"; }
have() { command -v "$1" >/dev/null 2>&1; }
ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

usage() { sed -n '2,26p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0; }

# ---------------------------------------------------------------- state ------
SHELL_DIR=""; SHELL_MODE=""; SHELL_VER=""; SHELL_WRITABLE=0  # SHELL_WRITABLE / PAYLOAD_OK are consumed by later stages
CONTENT=""; WIN=""; PAYLOAD_OK=0; PAYLOAD_ID=""
PLAN2=(); PLAN3=()
MODE=check; ASSUME_YES=0; FORCE=0; NO_REGISTER=0; NO_KEYBOARD=0; QMLLINT=""
PRIV=""; BACKUP_DIR=""; NEWDIR_NOTES=0; CREATED=(); REPLACED=()
MANIFEST="$CACHE/manifest.tsv"

# ------------------------------------------------------------ 1. preflight ---
step_preflight() {
  step "1/7 Preflight"
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    bad "Running as root. Run as your normal user (root would own your config files)."
  else
    ok "Running as normal user ($(id -un))"
  fi
  [[ -n "${HOME:-}" && -d "$HOME" ]] && ok "HOME is $HOME" || bad "HOME is not set"
  if [[ "$(uname -s)" == "Linux" ]]; then ok "Linux detected"; else bad "Not Linux ($(uname -s))"; fi

  local missing=()
  for t in sha256sum sort grep awk sed cmp find; do have "$t" || missing+=("$t"); done
  (( ${#missing[@]} )) && bad "Missing basic tools: ${missing[*]}" || ok "Basic tools present"

  if have python3; then ok "python3 available (needed to edit Caelestia files safely)"
  else warn "python3 not found: the tab cannot be registered automatically (files can still be copied)"; fi
  if have git; then ok "git available"
  elif have curl && have tar; then warn "git not found - will use curl+tar tarball download (no update diffing)"
  else bad "Need either git, or curl + tar, to download the Notes files"; fi
}

# --------------------------------------------------------- 2. locate shell ---
is_shell_dir() { [[ -f "$1/shell.qml" && -f "$1/modules/dashboard/Content.qml" ]]; }

step_locate_shell() {
  step "2/7 Locating your Caelestia shell"
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}"
  local user_dir="${CN_USER_DIR:-$conf/quickshell/caelestia}"
  local sys_dirs=()
  if [[ -n "${CN_SYS_DIR:-}" ]]; then sys_dirs=("$CN_SYS_DIR")
  else
    local IFS=:; local d
    for d in ${XDG_CONFIG_DIRS:-/etc/xdg}; do sys_dirs+=("$d/quickshell/caelestia"); done
  fi

  local have_user=0 sys_found=""
  is_shell_dir "$user_dir" && have_user=1
  local d; for d in "${sys_dirs[@]}"; do is_shell_dir "$d" && { sys_found="$d"; break; }; done

  (( have_user )) && info "User copy   : $user_dir  (found)" || info "User copy   : $user_dir  (not present)"
  [[ -n "$sys_found" ]] && info "System copy : $sys_found  (found)" || info "System copy : none found in ${sys_dirs[*]}"

  if (( have_user )); then SHELL_DIR="$user_dir"; SHELL_MODE="user"
  elif [[ -n "$sys_found" ]]; then SHELL_DIR="$sys_found"; SHELL_MODE="system"
  else
    bad "No Caelestia shell found. Install caelestia-shell first (https://github.com/caelestia-dots/shell)."
    return
  fi

  local real; real="$(readlink -f "$SHELL_DIR" 2>/dev/null || echo "$SHELL_DIR")"
  case "$real" in
    /nix/store/*|*/nix/store/*)
      SHELL_MODE="nix"
      bad "Shell lives in the Nix store (read-only): $real"
      info "Nix users: this installer cannot patch it. Use a home-manager/flake override instead."
      return ;;
  esac

  ok "Active shell directory: $SHELL_DIR  [$SHELL_MODE install]"
  CONTENT="$SHELL_DIR/modules/dashboard/Content.qml"
  WIN="$SHELL_DIR/modules/drawers/ContentWindow.qml"

  if [[ -w "$SHELL_DIR" && -w "$CONTENT" ]]; then SHELL_WRITABLE=1; ok "Directory is writable by you"
  else
    SHELL_WRITABLE=0
    if [[ "$SHELL_MODE" == "system" ]]; then
      warn "System copy is root-owned: --install will use sudo, only to write the Notes files and the two marked edits."
    else
      bad "Shell directory is not writable: $SHELL_DIR"
    fi
  fi

  if (( have_user )) && [[ -n "$sys_found" ]]; then
    warn "Your user copy shadows the system package at $sys_found."
    info "Package updates will NOT change what runs until your user copy is updated too."
  fi
  if have git && git -C "$SHELL_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    local br ch; br="$(git -C "$SHELL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    ch="$(git -C "$SHELL_DIR" status --porcelain 2>/dev/null | wc -l)"
    info "Git checkout: branch '$br', $ch locally changed/untracked file(s)"
  fi
}

# ------------------------------------------------------- 3. shell version ----
step_shell_version() {
  step "3/7 Shell version & compatibility"
  [[ -z "$SHELL_DIR" || "$SHELL_MODE" == "nix" ]] && { info "skipped (no usable shell)"; return; }
  local pkg="" gitv=""
  if have pacman; then
    pkg="$(pacman -Q caelestia-shell 2>/dev/null | awk '{print $2}')"
    [[ -z "$pkg" ]] && pkg="$(pacman -Q caelestia-shell-git 2>/dev/null | awk '{print $2}')"
    pkg="${pkg%%-*}"; pkg="${pkg#v}"
  fi
  if have git && git -C "$SHELL_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    gitv="$(git -C "$SHELL_DIR" describe --tags 2>/dev/null)"
  fi
  [[ -n "$pkg"  ]] && info "Installed package version : $pkg"
  [[ -n "$gitv" ]] && info "Git checkout describes as  : $gitv"

  if [[ "$SHELL_MODE" == "user" && -n "$gitv" ]]; then
    SHELL_VER="${gitv%%-*}"; SHELL_VER="${SHELL_VER#v}"
  elif [[ -n "$pkg" ]]; then SHELL_VER="$pkg"
  elif [[ -n "$gitv" ]]; then SHELL_VER="${gitv%%-*}"; SHELL_VER="${SHELL_VER#v}"
  fi

  if [[ ! "$SHELL_VER" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    warn "Could not determine a release version. The structural checks in step 7 decide compatibility."
    return
  fi
  if ! ver_ge "$SHELL_VER" "$MIN_VERSION"; then
    bad "Shell $SHELL_VER is older than $MIN_VERSION (oldest release checked against the Notes code)."
  elif [[ " $TESTED_VERSIONS " == *" $SHELL_VER "* ]]; then
    ok "Shell $SHELL_VER - runtime-tested by the author"
  else
    warn "Shell $SHELL_VER - dependency surface checked statically, but not runtime-tested (tested: $TESTED_VERSIONS)"
  fi
}

# ------------------------------------------------------- 4. dependencies ----
step_dependencies() {
  step "4/7 Dependencies"
  local qs=""; have quickshell && qs=quickshell; [[ -z "$qs" ]] && have qs && qs=qs
  if [[ -n "$qs" ]]; then ok "quickshell: $("$qs" --version 2>/dev/null | head -n1)"
  else bad "quickshell not found in PATH"; fi
  have caelestia && ok "caelestia CLI present (used later to restart the shell)" \
                 || warn "caelestia CLI not found - restart step will fall back to 'qs -c caelestia'"

  local dirs=() d
  if have qmake6; then d="$(qmake6 -query QT_INSTALL_QML 2>/dev/null)"; [[ -n "$d" ]] && dirs+=("$d"); fi
  dirs+=(/usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/qt/qml /usr/lib/x86_64-linux-gnu/qt6/qml)
  if [[ -n "${CN_QML_DIRS:-}" ]]; then local IFS=:; for d in $CN_QML_DIRS; do dirs+=("$d"); done; fi

  local found_m3="" found_cae=""
  for d in "${dirs[@]}"; do
    [[ -z "$found_m3"  && -f "$d/M3Shapes/qmldir"  ]] && found_m3="$d/M3Shapes"
    [[ -z "$found_cae" && -d "$d/Caelestia/Config" ]] && found_cae="$d/Caelestia"
  done
  [[ -n "$found_m3"  ]] && ok "M3Shapes QML module: $found_m3" \
    || bad "M3Shapes QML module not found (Arch: qt6-m3shapes-git). Markdown/Todo views need it."
  [[ -n "$found_cae" ]] && ok "Caelestia QML plugin: $found_cae" \
    || warn "Caelestia QML plugin not found in standard paths (may be in a custom location - not fatal)"
}

# ------------------------------------------------------- 5. fetch payload ---
step_fetch_payload() {
  local script_dir; script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [[ -f "$script_dir/modules/dashboard/NotesTab.qml" && -f "$script_dir/services/NotesStore.qml" && -f "$script_dir/config/notes.default.json" ]]; then
    SRC="$script_dir"
    PAYLOAD_ID="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo local)"
    ok "Using local repository at $SRC ($PAYLOAD_ID)"
    return
  fi
  mkdir -p "$CACHE" || { bad "Cannot create cache dir $CACHE"; return; }
  info "Source: $REPO_URL  (branch $BRANCH)"
  if have git; then
    local before=""
    if [[ -d "$SRC/.git" ]]; then
      before="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
      if git -C "$SRC" fetch --quiet --depth 1 "$REPO_URL" "$BRANCH" 2>/dev/null \
         && git -C "$SRC" reset --quiet --hard FETCH_HEAD 2>/dev/null \
         && git -C "$SRC" clean -qfd 2>/dev/null; then :
      else bad "Could not update cached copy from $REPO_URL"; return; fi
    else
      rm -rf "$SRC"
      git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$SRC" 2>/dev/null \
        || { bad "git clone failed for $REPO_URL (offline? wrong URL/branch?)"; return; }
    fi
    PAYLOAD_ID="$(git -C "$SRC" rev-parse --short HEAD)"
    local subj; subj="$(git -C "$SRC" log -1 --format='%s' 2>/dev/null)"
    if [[ -z "$before" ]]; then ok "Cloned at commit $PAYLOAD_ID  ($subj)"
    elif [[ "$before" == "$PAYLOAD_ID" ]]; then ok "Cache already up to date at $PAYLOAD_ID"
    else ok "Cache updated $before -> $PAYLOAD_ID  ($subj)"; fi
  else
    local tmp; tmp="$(mktemp -d)"; local url="${REPO_URL%.git}"
    url="${url/github.com/codeload.github.com}/tar.gz/refs/heads/$BRANCH"
    if curl -fsSL "$url" -o "$tmp/r.tgz" && mkdir -p "$tmp/x" && tar -xzf "$tmp/r.tgz" -C "$tmp/x" --strip-components=1; then
      rm -rf "$SRC"; mv "$tmp/x" "$SRC"; PAYLOAD_ID="tar-$(sha256sum "$tmp/r.tgz" | cut -c1-8)"
      ok "Downloaded tarball ($PAYLOAD_ID)"
    else bad "Tarball download failed: $url"; fi
    rm -rf "$tmp"
  fi
}

# Only a Qt 6 qmllint is usable: on Arch, plain `qmllint` is often the Qt 5 binary,
# which cannot parse Qt 6 files and would report bogus errors. So check the version.
find_qmllint() {
  QMLLINT=""; local q qv
  for q in qmllint6 /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint /usr/lib/qt/bin/qmllint qmllint; do
    if have "$q" || [[ -x "$q" ]]; then
      qv="$("$q" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
      if [[ "${qv%%.*}" == 6 ]]; then QMLLINT="$q"; break; fi
    fi
  done
}
lint_ok() { [[ -n "$QMLLINT" ]] || return 0; ! "$QMLLINT" "$1" 2>&1 | grep -qiE 'syntax error|unexpected token|expected token|parse error'; }

# ------------------------------------------------------ 6. verify payload ---
payload_files() { (cd "$SRC" && find modules services -type f 2>/dev/null | sort); }

step_verify_payload() {
  step "6/7 Verifying Notes files"
  [[ -d "$SRC" && -n "$PAYLOAD_ID" ]] || { bad "No payload to verify"; return; }
  local p=0 req
  for req in modules/dashboard/NotesTab.qml services/NotesStore.qml config/notes.default.json; do
    if [[ -s "$SRC/$req" ]]; then :; else bad "Required file missing or empty: $req"; p=1; fi
  done
  ls "$SRC"/modules/dashboard/notes/*.qml >/dev/null 2>&1 || { bad "No QML files in modules/dashboard/notes/"; p=1; }

  local files; files="$(payload_files)"
  local n; n="$(grep -c . <<<"$files")"
  (( p == 0 )) && ok "All required files present ($n files to install under modules/ and services/)"

  # only .qml files may be installed into the shell
  local odd; odd="$(grep -vE '\.qml$' <<<"$files" || true)"
  [[ -n "$odd" ]] && { bad "Non-QML files under modules/ or services/ (refusing): $(tr '\n' ' ' <<<"$odd")"; p=1; }
  # nothing may try to escape its directory
  if grep -qE '(^|/)\.\.(/|$)' <<<"$files"; then bad "Path traversal in payload file list"; p=1; fi
  # symlinks are never allowed in the payload
  if [[ -n "$(cd "$SRC" && find modules services config -type l 2>/dev/null)" ]]; then bad "Symlinks in payload (refusing)"; p=1; fi

  # security audit: Notes must not run programs or use the network
  local hits; hits="$(cd "$SRC" && grep -rnE 'Process[[:space:]]*\{|execDetached|XMLHttpRequest|[^a-zA-Z.]fetch\(|WebSocket|SocketServer|NetworkAccess|Quickshell\.Services' modules services 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then bad "Audit: payload runs programs / uses network:"; sed 's/^/           /' <<<"$hits"; p=1
  else ok "Audit: no process execution, no network access in the QML"; fi
  local links; links="$(cd "$SRC" && grep -rc 'Qt.openUrlExternally' modules services 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
  (( links > 0 )) && info "Note: $links link handler(s) open URLs in your browser, only when you click a link in a note"

  # JSON sanity
  if have python3; then
    python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$SRC/config/notes.default.json" 2>/dev/null \
      && ok "notes.default.json is valid JSON" || { bad "notes.default.json is not valid JSON"; p=1; }
  elif have jq; then
    jq empty "$SRC/config/notes.default.json" 2>/dev/null && ok "notes.default.json is valid JSON" || { bad "notes.default.json invalid"; p=1; }
  else info "No python3/jq: skipped JSON validation"; fi

  # QML syntax (best effort; only genuine parse errors count)
  find_qmllint; local ql="$QMLLINT"
  if [[ -n "$ql" ]]; then
    local f errs=0 out
    while IFS= read -r f; do
      out="$("$ql" "$SRC/$f" 2>&1 | grep -iE 'syntax error|unexpected token|expected token|parse error' || true)"
      [[ -n "$out" ]] && { errs=1; bad "QML syntax problem in $f: $(head -n1 <<<"$out")"; }
    done <<<"$files"
    (( errs == 0 )) && ok "qmllint: no syntax errors" || p=1
  else info "No Qt 6 qmllint found (a Qt 5 one is ignored): skipped QML syntax check"; fi

  # fingerprint of exactly what would be installed
  local fp; fp="$({ printf '%s\n' "$files"; echo config/notes.default.json; } | (cd "$SRC" && xargs -d '\n' sha256sum) | sha256sum | cut -c1-16)"
  info "Payload fingerprint: $fp  (commit $PAYLOAD_ID)"
  (( p == 0 )) && PAYLOAD_OK=1
}

# ------------------------------------------------- 7. analyse the shell ------
cmp_state() { [[ -e "$1" ]] || { echo absent; return; }; cmp -s "$1" "$2" && echo identical || echo differs; }

step_analyze_targets() {
  step "7/7 Checking your shell files (read-only)"
  [[ -n "$SHELL_DIR" && "$SHELL_MODE" != "nix" ]] || { info "skipped (no usable shell)"; return; }

  # --- Content.qml : where the tab gets registered
  if [[ ! -f "$CONTENT" ]]; then bad "modules/dashboard/Content.qml missing"; else
    local t_perf c_perf t_weat c_weat integ label i18n
    t_perf=$(grep -c 'component: performanceComponent,' "$CONTENT"); c_perf=$(grep -c 'id: performanceComponent' "$CONTENT")
    t_weat=$(grep -c 'component: weatherComponent,'     "$CONTENT"); c_weat=$(grep -c 'id: weatherComponent' "$CONTENT")
    integ=$(grep -c 'notesComponent' "$CONTENT")
    if grep -q 'Tr\.tr(' "$CONTENT"; then label="Tr.tr"; elif grep -q 'qsTr(' "$CONTENT"; then label="qsTr"; else label="unknown"; fi
    grep -q 'import Caelestia.I18n' "$CONTENT" && i18n=yes || i18n=no
    info "Tab label function in this shell: $label (Caelestia.I18n imported: $i18n)"

    local managed; managed=$(grep -c '>>> caelestia-notes' "$CONTENT")
    if (( managed > 0 )); then
      ok "Notes tab registration is managed by this installer (failure-safe loader)"
    elif (( integ > 0 )); then
      if [[ -f "$SHELL_DIR/modules/dashboard/NotesTab.qml" ]]; then
        warn "Content.qml has a manual Notes registration (direct 'NotesTab {}'): if the Notes files ever break, the WHOLE dashboard fails to load."
        PLAN3+=("Content.qml: convert your manual registration into the failure-safe managed block (backup first)")
      else
        warn "Content.qml references Notes but NotesTab.qml is missing: the dashboard cannot load right now. --install repairs this."
        PLAN3+=("Content.qml: replace the dangling registration with the failure-safe managed block")
      fi
    elif (( t_perf == 1 && c_perf == 1 )); then
      ok "Patch anchors found (tab list + component list, before 'performance')"
      PLAN3+=("Content.qml: add the Notes tab (marked block, failure-safe loader; backup first)")
    elif (( t_weat == 1 && c_weat == 1 )); then
      warn "Performance anchors missing; fallback anchors (weather) are present"
      PLAN3+=("Content.qml: add Notes tab + component using fallback anchor")
    else
      bad "Could not find a safe place in Content.qml to add the tab (shell layout changed?)"
    fi
  fi

  # --- ContentWindow.qml : keyboard focus so typing works
  if [[ ! -f "$WIN" ]]; then warn "modules/drawers/ContentWindow.qml missing - typing cannot be enabled automatically"; else
    local kline; kline="$(grep -m1 'WlrLayershell.keyboardFocus:' "$WIN" | sed 's/^[[:space:]]*//')"
    if [[ -z "$kline" ]]; then
      warn "No keyboardFocus line in ContentWindow.qml: typing in Notes may not work"
    elif grep -q '>>> caelestia-notes' "$WIN"; then
      ok "Keyboard focus edit is managed by this installer (typing will work)"
    elif [[ "$kline" == *screenState.dashboard* ]]; then
      ok "Keyboard focus already allows the dashboard (typing will work)"
    elif [[ "$kline" == "$KBD_PRISTINE" ]]; then
      warn "Keyboard focus is stock: typing in Notes will NOT work until 1 line is patched in ContentWindow.qml"
      PLAN3+=("ContentWindow.qml: let the dashboard take keyboard focus so typing works (marked block; backup first)")
    else
      warn "keyboardFocus line is customised; it will not be auto-patched: $kline"
    fi
  fi

  # --- do our files already exist in the shell?
  local f st absent=0 ident=0 diff=0 list
  list="$(payload_files 2>/dev/null)"
  if [[ -n "$list" ]]; then
    while IFS= read -r f; do
      st="$(cmp_state "$SHELL_DIR/$f" "$SRC/$f")"
      case "$st" in absent) absent=$((absent+1));; identical) ident=$((ident+1));; differs) diff=$((diff+1));; esac
    done <<<"$list"
    info "Notes files in shell dir: $ident identical, $diff different, $absent not installed yet"
    (( diff > 0 )) && warn "$diff existing file(s) differ from the repo (older version or local edits). They will be backed up before replacing."
    (( absent + diff > 0 )) && PLAN2+=("Copy $((absent+diff)) QML file(s) into modules/dashboard/ and services/")
    (( absent == 0 && diff == 0 )) && ok "Installed Notes files match the repo exactly"
  fi

  # --- user config / data (we never overwrite user data)
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia" st_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
  [[ -d "$st_dir" ]] && ok "State dir exists: $st_dir" || { warn "State dir missing; it will be created"; PLAN2+=("Create $st_dir"); }
  if [[ -f "$st_dir/notes.json" ]]; then ok "Your notes data exists ($(wc -c <"$st_dir/notes.json") bytes) - will never be overwritten"
  else info "No notes data yet (will initialise with starter notes and todos)"; PLAN2+=("Initialise starter notes data at $st_dir/notes.json"); fi
  case "$(cmp_state "$cfg/notes.default.json" "$SRC/config/notes.default.json")" in
    absent) PLAN2+=("Copy starter template to $cfg/notes.default.json");;
    differs) info "Starter template differs from repo version (will be refreshed; it is not your data)";;
  esac

  # --- shell running right now?
  local running=0 pid
  for pid in $(pgrep -x quickshell 2>/dev/null) $(pgrep -x qs 2>/dev/null); do
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q 'caelestia' && running=1
  done
  if (( running )); then info "The Caelestia shell is currently running (a later stage restarts it, with a health check)"
  else info "Caelestia shell does not appear to be running right now"; fi
}

# =============================================================================
#  STAGE 2: install / uninstall the Notes FILES (never edits Caelestia's own files)
# =============================================================================
STAMP="$(date +%Y%m%d-%H%M%S)"

confirm() {   # confirm "question"  -> 0 = yes
  (( ASSUME_YES )) && return 0
  if { : </dev/tty; } 2>/dev/null; then
    local a; read -r -p "  ? $1 [y/N] " a </dev/tty; [[ "$a" == [yY]* ]]
  else
    warn "No terminal available to ask: \"$1\"  -> re-run with --yes to accept."; return 1
  fi
}

manifest_sha() {  # manifest_sha KIND PATH -> recorded sha256 or empty
  [[ -f "$MANIFEST" ]] || return 0
  awk -F'\t' -v k="$1" -v p="$2" '$1==k && $3==p {print $2}' "$MANIFEST"
}

# Does this file belong to the shell itself (upstream git / pacman package)?
is_upstream_owned() {
  local f="$1"
  if have git && git -C "$SHELL_DIR" rev-parse --git-dir >/dev/null 2>&1 \
     && git -C "$SHELL_DIR" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then return 0; fi
  if have pacman && pacman -Qo "$SHELL_DIR/$f" >/dev/null 2>&1; then return 0; fi
  return 1
}

rollback_files() {
  warn "Rolling back: restoring your shell to exactly how it was"
  local f
  for f in ${CREATED[@]+"${CREATED[@]}"}; do $PRIV rm -f "$SHELL_DIR/$f" "$SHELL_DIR/$f.cn-tmp" 2>/dev/null; done
  for f in ${REPLACED[@]+"${REPLACED[@]}"}; do $PRIV cp -p "$BACKUP_DIR/files/$f" "$SHELL_DIR/$f" 2>/dev/null; $PRIV rm -f "$SHELL_DIR/$f.cn-tmp" 2>/dev/null; done
  (( NEWDIR_NOTES )) && $PRIV rmdir "$SHELL_DIR/modules/dashboard/notes" 2>/dev/null
  info "Rollback finished. Backups (if any) are in: ${BACKUP_DIR:-none}"
}

pick_priv() {
  PRIV=""
  if [[ -w "$SHELL_DIR" ]]; then return 0; fi
  if [[ "$SHELL_MODE" == "system" ]] && have sudo; then
    PRIV="sudo"; info "Shell directory is root-owned: sudo will be used ONLY to write the Notes files and the marked edits"
  else bad "Cannot write to $SHELL_DIR (and sudo is not an option here)"; return 1; fi
}

stage2_install() {
  step "Stage 2 - installing Notes files"
  (( PAYLOAD_OK )) || { bad "Payload did not verify; refusing to install"; return 1; }
  pick_priv || return 1
  local list f dest st sha_now sha_man
  list="$(payload_files)"
  local to_write=() foreign=() upstream=()
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    dest="$SHELL_DIR/$f"; st="$(cmp_state "$dest" "$SRC/$f")"
    case "$st" in
      absent) to_write+=("$f");;
      differs)
        if is_upstream_owned "$f"; then upstream+=("$f")
        else
          sha_now="$(sha256sum "$dest" | cut -d' ' -f1)"; sha_man="$(manifest_sha S "$f")"
          to_write+=("$f")
          [[ -n "$sha_man" && "$sha_now" == "$sha_man" ]] || foreign+=("$f")   # not ours-unmodified
        fi;;
    esac
  done <<<"$list"

  if (( ${#upstream[@]} )); then
    if (( FORCE )); then
      warn "--force: overriding files that belong to the shell (they will be backed up):"
      printf '           %s\n' "${upstream[@]}"; to_write+=("${upstream[@]}"); foreign+=("${upstream[@]}")
    else
      bad "These files belong to the shell itself (tracked upstream or owned by the package). The shell wins; refusing:"
      printf '           %s\n' "${upstream[@]}"
      info "If this is your own fork and you really want to replace them, re-run with --force."
      return 1
    fi
  fi

  # Template + state dir (user-owned; never touches notes.json)
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia" st_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
  local tpl="$cfg/notes.default.json" tpl_state; tpl_state="$(cmp_state "$tpl" "$SRC/config/notes.default.json")"

  if (( ${#to_write[@]} == 0 )) && [[ "$tpl_state" == identical ]]; then
    ok "Everything is already installed and up to date - no files changed"
    mkdir -p "$st_dir"
    write_manifest || return 1
    return 0
  fi

  if (( ${#foreign[@]} )); then
    warn "These existing files are locally modified (or not installed by this installer). They will be BACKED UP, then replaced:"
    printf '           %s\n' "${foreign[@]}"
    confirm "Replace them?" || { info "Aborted. Nothing was changed."; return 1; }
  fi
  confirm "Install ${#to_write[@]} file(s) into $SHELL_DIR ?" || { info "Aborted. Nothing was changed."; return 1; }

  BACKUP_DIR="$CACHE/backups/$STAMP"; mkdir -p "$BACKUP_DIR/files" "$BACKUP_DIR/home" || { bad "Cannot create backup dir"; return 1; }
  CREATED=(); REPLACED=(); NEWDIR_NOTES=0
  [[ -d "$SHELL_DIR/modules/dashboard/notes" ]] || NEWDIR_NOTES=1

  # 1) back up everything we are about to replace
  for f in "${to_write[@]}"; do
    if [[ -e "$SHELL_DIR/$f" ]]; then
      mkdir -p "$BACKUP_DIR/files/$(dirname "$f")" && cp -p "$SHELL_DIR/$f" "$BACKUP_DIR/files/$f" \
        || { bad "Backup of $f failed - nothing was changed"; return 1; }
      REPLACED+=("$f")
    else CREATED+=("$f"); fi
  done
  [[ -e "$tpl" ]] && cp -p "$tpl" "$BACKUP_DIR/home/notes.default.json"
  (( ${#REPLACED[@]} )) && ok "Backed up ${#REPLACED[@]} existing file(s) to $BACKUP_DIR"

  # 2) write each file next to its destination, then rename into place (atomic per file)
  for f in "${to_write[@]}"; do
    dest="$SHELL_DIR/$f"
    if ! { $PRIV mkdir -p "$(dirname "$dest")" && $PRIV install -m 644 "$SRC/$f" "$dest.cn-tmp" && $PRIV mv -f "$dest.cn-tmp" "$dest"; } 2>/dev/null; then
      bad "Failed writing $f"; rollback_files; return 1
    fi
  done

  # 3) verify what landed on disk
  for f in "${to_write[@]}"; do
    if ! cmp -s "$SRC/$f" "$SHELL_DIR/$f"; then bad "Verification failed for $f"; rollback_files; return 1; fi
  done
  if (( ${#to_write[@]} )); then ok "Installed and verified ${#to_write[@]} file(s)"; else ok "Notes files already up to date (only the starter template changed)"; fi

  # 4) user-side files
  mkdir -p "$st_dir" "$cfg" && install -m 644 "$SRC/config/notes.default.json" "$tpl" \
    && ok "Starter template placed at $tpl" || warn "Could not write $tpl (Notes still works; it just starts empty)"
  if [[ -f "$st_dir/notes.json" ]]; then
    ok "Your existing notes data was left untouched"
  else
    install -m 644 "$SRC/config/notes.default.json" "$st_dir/notes.json" \
      && ok "Initialised notes data with starter content at $st_dir/notes.json"
  fi

  write_manifest || return 1
  return 0
}

write_manifest() {
  local tmp="$MANIFEST.tmp" f
  # keep the pointer to the last real backup if this run made none
  [[ -z "$BACKUP_DIR" && -f "$MANIFEST" ]] && BACKUP_DIR="$(sed -n 's/^# backup=//p' "$MANIFEST")"
  {
    printf '# caelestia-notes manifest\n# shell_dir=%s\n# mode=%s\n# commit=%s\n# installed=%s\n# backup=%s\n' \
      "$SHELL_DIR" "$SHELL_MODE" "$PAYLOAD_ID" "$STAMP" "${BACKUP_DIR:-}"
    while IFS= read -r f; do
      [[ -n "$f" ]] && printf 'S\t%s\t%s\n' "$(sha256sum "$SHELL_DIR/$f" | cut -d' ' -f1)" "$f"
    done <<<"$(payload_files)"
    local tpl="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/notes.default.json"
    if [[ -f "$tpl" ]]; then printf 'H\t%s\t%s\n' "$(sha256sum "$tpl" | cut -d' ' -f1)" "$tpl"; fi
    for f in modules/dashboard/Content.qml modules/drawers/ContentWindow.qml; do
      if grep -q '>>> caelestia-notes' "$SHELL_DIR/$f" 2>/dev/null; then
        printf 'P\t%s\t%s\n' "$(sha256sum "$SHELL_DIR/$f" | cut -d' ' -f1)" "$f"
      fi
    done
    true
  } >"$tmp" || { bad "Could not write the manifest"; return 1; }
  mv -f "$tmp" "$MANIFEST" || { bad "Could not write the manifest"; return 1; }
  info "Manifest written: $MANIFEST"
  return 0
}

stage2_uninstall() {
  step "Uninstall - removing Notes files"
  [[ -f "$MANIFEST" ]] || { bad "No manifest at $MANIFEST: nothing is recorded as installed by this installer."; return 1; }
  local dir bk kind sha path
  dir="$(sed -n 's/^# shell_dir=//p' "$MANIFEST")"; bk="$(sed -n 's/^# backup=//p' "$MANIFEST")"
  [[ -d "$dir" ]] || { bad "Recorded shell directory no longer exists: $dir"; return 1; }
  SHELL_DIR="$dir"; BACKUP_DIR="$bk"
  local content="$dir/modules/dashboard/Content.qml"
  SHELL_MODE="$(sed -n 's/^# mode=//p' "$MANIFEST")"; [[ -n "$SHELL_MODE" ]] || SHELL_MODE="user"
  CONTENT="$content"; WIN="$dir/modules/drawers/ContentWindow.qml"
  pick_priv || return 1
  confirm "Unregister the Notes tab and remove the Notes files recorded in the manifest ($dir) ?" || { info "Aborted."; return 1; }
  # 1) take the tab out of the shell first, so no file is deleted while something still loads it
  stage3_unregister || return 1
  if grep -q 'notesComponent' "$content" 2>/dev/null && (( ! FORCE )); then
    bad "Content.qml still has a manual (unmanaged) Notes registration. Deleting the files now would break your dashboard."
    info "Run --install once to convert it to the managed block, or remove it by hand, or use --force."
    return 1
  fi
  local removed=0 kept=0 restored=0 now
  while IFS=$'\t' read -r kind sha path; do
    [[ "$kind" == S || "$kind" == H ]] || continue
    local target="$path"; [[ "$kind" == S ]] && target="$dir/$path"
    [[ -e "$target" ]] || continue
    now="$(sha256sum "$target" | cut -d' ' -f1)"
    if [[ "$now" == "$sha" ]]; then
      if [[ "$kind" == S ]]; then $PRIV rm -f "$target"; else rm -f "$target"; fi; removed=$((removed+1))
      if [[ "$kind" == S && -n "$bk" && -f "$bk/files/$path" ]]; then $PRIV cp -p "$bk/files/$path" "$target" && restored=$((restored+1)); fi
      if [[ "$kind" == H && -n "$bk" && -f "$bk/home/notes.default.json" ]]; then cp -p "$bk/home/notes.default.json" "$target"; fi
    else
      kept=$((kept+1)); warn "Left in place (modified since install): $target"
    fi
  done < <(grep -v '^#' "$MANIFEST")
  $PRIV rmdir "$dir/modules/dashboard/notes" 2>/dev/null
  mv -f "$MANIFEST" "$CACHE/manifest.uninstalled-$STAMP.tsv"
  ok "Removed $removed file(s), restored $restored original(s) from backup, left $kept modified file(s)"
  ok "Your notes data (~/.local/state/caelestia/notes.json) was NOT touched"
}

# =============================================================================
#  STAGE 3: register the tab (edits 2 Caelestia files via marked, reversible blocks)
# =============================================================================
# The patcher is embedded so `curl | bash` stays a single file. Exit codes:
# 0 ok, 2 refused (unexpected shape), 3 skipped (nothing safe to change).
cn_patch() { python3 - "$@" <<'PYEOF'
import re, sys

BEG = ">>> caelestia-notes"
END = "<<< caelestia-notes"
PRISTINE_KBD = "screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"
NEW_KBD = "screenState.launcher || screenState.session || screenState.dashboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"


class Err(Exception):
    pass


def norm(s):
    return re.sub(r"\s+", " ", s.strip())


def is_c(line, tag):
    return line.lstrip().startswith("//") and tag in line


def managed_ranges(ls):
    out, i = [], 0
    while i < len(ls):
        if is_c(ls[i], BEG):
            j = i + 1
            while j < len(ls) and not is_c(ls[j], END):
                if is_c(ls[j], BEG):
                    raise Err("nested/unterminated managed block")
                j += 1
            if j >= len(ls):
                raise Err("unterminated managed block")
            out.append((i, j))
            i = j + 1
        else:
            i += 1
    return out


def drop_ranges(ls, ranges):
    for a, b in sorted(ranges, reverse=True):
        del ls[a:b + 1]
        # collapse a double blank line left behind by removing a block
        if 0 < a < len(ls) and ls[a].strip() == "" and ls[a - 1].strip() == "":
            del ls[a]
    return ls


# ----------------------------------------------------------------- Content.qml
def tab_block(ind, fn):
    return [
        f"{ind}// {BEG}: managed block - do not edit; `install.sh --uninstall` removes it >>>",
        f"{ind}{{",
        f"{ind}    component: notesComponent,",
        f'{ind}    iconName: "edit_note",',
        f'{ind}    text: {fn}("Notes"),',
        f"{ind}    enabled: true",
        f"{ind}}},",
        f"{ind}// {END} <<<",
    ]


def comp_block(ind, fn):
    L = [
        f"// {BEG}: managed block - do not edit; `install.sh --uninstall` removes it >>>",
        "Component {",
        "    id: notesComponent",
        "",
        '    // A wrapper Item + URL Loader (not a direct "NotesTab {}") so that a missing or broken',
        "    // Notes file can never stop this file - and therefore the whole dashboard - from loading.",
        "    Item {",
        "        implicitWidth: notesLoader.item ? notesLoader.item.implicitWidth : 840",
        "        implicitHeight: notesLoader.item ? notesLoader.item.implicitHeight : 480",
        "",
        "        Loader {",
        "            id: notesLoader",
        "",
        "            anchors.fill: parent",
        '            source: Qt.resolvedUrl("NotesTab.qml")',
        "        }",
        "",
        "        StyledText {",
        "            anchors.centerIn: parent",
        "            visible: notesLoader.status === Loader.Error",
        f'            text: {fn}("Notes failed to load. Re-run the Caelestia Notes installer.")',
        "        }",
        "    }",
        "}",
        f"// {END} <<<",
    ]
    return [(ind + l) if l else "" for l in L] + [""]


def find_unmanaged_notes(ls):
    idx = [i for i, l in enumerate(ls) if re.search(r"component:\s*notesComponent\b", l)]
    cid = [i for i, l in enumerate(ls) if re.search(r"\bid:\s*notesComponent\b", l)]
    if not idx and not cid:
        return None
    if len(idx) != 1 or len(cid) != 1:
        raise Err("existing Notes registration has an unexpected shape (not touching it)")
    s = idx[0]
    while s >= 0 and not re.match(r"^\s*\{\s*$", ls[s]):
        s -= 1
    e = idx[0]
    while e < len(ls) and not re.match(r"^\s*\},?\s*$", ls[e]):
        e += 1
    if s < 0 or e >= len(ls):
        raise Err("cannot find the existing Notes tab entry bounds")
    keys = set(re.findall(r"^\s*(\w+):", "\n".join(ls[s + 1:e]), re.M))
    if not keys <= {"component", "iconName", "text", "enabled"}:
        raise Err("existing Notes tab entry is customised (not touching it)")
    cs = cid[0]
    while cs >= 0 and not re.match(r"^\s*Component\s*\{\s*$", ls[cs]):
        cs -= 1
    if cs < 0:
        raise Err("cannot find the existing Notes Component")
    depth, ce = 0, None
    for k in range(cs, len(ls)):
        depth += ls[k].count("{") - ls[k].count("}")
        if depth == 0:
            ce = k
            break
    if ce is None or (ce - cs) > 14 or "NotesTab" not in "\n".join(ls[cs:ce + 1]):
        raise Err("existing Notes Component is customised (not touching it)")
    return (s, e), (cs, ce)


def anchors(ls):
    for name in ("performanceComponent", "weatherComponent"):
        t = [i for i, l in enumerate(ls) if re.search(r"component:\s*" + name + r"\b", l)]
        c = [i for i, l in enumerate(ls) if re.search(r"\bid:\s*" + name + r"\b", l)]
        if len(t) == 1 and len(c) == 1:
            ts = t[0]
            while ts >= 0 and not re.match(r"^\s*\{\s*$", ls[ts]):
                ts -= 1
            cs = c[0]
            while cs >= 0 and not re.match(r"^\s*Component\s*\{\s*$", ls[cs]):
                cs -= 1
            if ts >= 0 and cs >= 0:
                return ts, cs
    raise Err("no safe place found in Content.qml (the shell layout changed)")


def content_install(ls, fn):
    status = "inserted"
    mr = managed_ranges(ls)
    if mr:
        drop_ranges(ls, mr)
        status = "refreshed"
    else:
        un = find_unmanaged_notes(ls)
        if un:
            (a, b), (c, d) = un
            drop_ranges(ls, [(a, b), (c, d)])
            status = "converted"
    ts, cs = anchors(ls)
    ci = re.match(r"^(\s*)", ls[cs]).group(1)
    ti = re.match(r"^(\s*)", ls[ts]).group(1)
    ls[cs:cs] = comp_block(ci, fn)      # higher index first so ts stays valid
    ls[ts:ts] = tab_block(ti, fn)
    return ls, status


def content_remove(ls):
    mr = managed_ranges(ls)
    if not mr:
        return ls, "nothing-to-remove"
    return drop_ranges(ls, mr), "removed"


# ------------------------------------------------------------ ContentWindow.qml
KBD_RE = re.compile(r"^(\s*)WlrLayershell\.keyboardFocus:\s*(.*)$")


def window_install(ls):
    mr = managed_ranges(ls)
    if mr:
        # refresh: restore the original first, then re-apply
        ls, _ = window_remove(ls)
    hits = [i for i, l in enumerate(ls) if KBD_RE.match(l)]
    if len(hits) != 1:
        return ls, "no-keyboard-line", 3
    i = hits[0]
    ind, expr = KBD_RE.match(ls[i]).groups()
    if "screenState.dashboard" in expr:
        return ls, "already-allows", 3
    if norm(expr) != PRISTINE_KBD:
        return ls, "customised", 3
    orig = ls[i].strip()
    ls[i:i + 1] = [
        f"{ind}// {BEG}: lets the dashboard take keyboard focus so you can type in Notes >>>",
        f"{ind}// original: {orig}",
        f"{ind}WlrLayershell.keyboardFocus: {NEW_KBD}",
        f"{ind}// {END} <<<",
    ]
    return ls, "inserted", 0


def window_remove(ls):
    mr = managed_ranges(ls)
    if not mr:
        return ls, "nothing-to-remove"
    for a, b in sorted(mr, reverse=True):
        orig = None
        for k in range(a, b + 1):
            m = re.match(r"^(\s*)//\s*original:\s*(.*)$", ls[k])
            if m:
                ind, orig = m.groups()
        if orig is None:
            raise Err("managed block has no saved original line")
        ls[a:b + 1] = [f"{ind}{orig}"]
    return ls, "removed"


# ------------------------------------------------------------------------ main
def main():
    kind, mode, src, dst = sys.argv[1:5]
    fn = sys.argv[5] if len(sys.argv) > 5 else "qsTr"
    text = open(src, encoding="utf-8").read()
    ls = text.split("\n")
    code = 0
    try:
        if kind == "content" and mode == "install":
            ls, status = content_install(ls, fn)
        elif kind == "content" and mode == "remove":
            ls, status = content_remove(ls)
        elif kind == "window" and mode == "install":
            ls, status, code = window_install(ls)
        elif kind == "window" and mode == "remove":
            ls, status = window_remove(ls)
        else:
            raise Err("bad arguments")
        new = "\n".join(ls)
        # safety nets
        if new.count("{") - new.count("}") != text.count("{") - text.count("}"):
            raise Err("internal check failed: brace balance changed")
        if mode == "install" and code == 0:
            if new.count(BEG) != new.count(END) or new.count(BEG) < 1:
                raise Err("internal check failed: markers")
        if new != text:
            open(dst, "w", encoding="utf-8").write(new)
            print(f"STATUS {status} changed")
        else:
            print(f"STATUS {status} unchanged")
        sys.exit(code)
    except Err as e:
        print(f"ERROR {e}")
        sys.exit(2)


main()
PYEOF
}

label_fn() { if grep -q 'Tr\.tr(' "$1"; then echo "Tr.tr"; else echo "qsTr"; fi; }

write_priv() {   # write_priv SRC DEST : atomic replace, keeps DEST's permissions
  local mode; mode="$(stat -c %a "$2" 2>/dev/null || echo 644)"
  $PRIV install -m "$mode" "$1" "$2.cn-tmp" && $PRIV mv -f "$2.cn-tmp" "$2"
}

stage3_register() {
  step "Stage 3 - registering the Notes tab"
  if (( NO_REGISTER )); then info "Skipped (--no-register): files are installed, the tab is not registered."; return 0; fi
  have python3 || { warn "python3 not found: cannot edit Content.qml safely. Files are installed, tab NOT registered."; return 0; }
  pick_priv || return 1
  find_qmllint
  local tmp fn cs ws wcode ccode cch=0 wch=0
  tmp="$(mktemp -d)"; fn="$(label_fn "$CONTENT")"

  cs="$(cn_patch content install "$CONTENT" "$tmp/Content.qml" "$fn")"; ccode=$?
  if (( ccode != 0 )); then
    bad "Cannot safely edit Content.qml: ${cs#ERROR }"
    info "Notes files are installed but the tab was NOT registered. No Caelestia file was changed."
    rm -rf "$tmp"; return 1
  fi
  [[ "$cs" == *" changed" ]] && cch=1
  ws=""; wcode=0
  if (( NO_KEYBOARD )); then info "Skipping the keyboard-focus edit (--no-keyboard): typing in Notes may not work."
  else
    ws="$(cn_patch window install "$WIN" "$tmp/ContentWindow.qml")"; wcode=$?
    case "$wcode:$ws" in
      0:*" changed") wch=1;;
      0:*) ;;
      3:*already-allows*) ok "Keyboard focus already allows the dashboard - nothing to change";;
      3:*customised*) warn "keyboardFocus line in ContentWindow.qml is customised; left alone (typing in Notes may not work)";;
      3:*) warn "No keyboardFocus line found in ContentWindow.qml; left alone (typing in Notes may not work)";;
      *) bad "Cannot safely edit ContentWindow.qml: ${ws#ERROR }"; rm -rf "$tmp"; return 1;;
    esac
  fi

  if (( ! cch && ! wch )); then
    ok "Tab registration is already up to date - no Caelestia file changed"
    write_manifest || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"; return 0
  fi

  # never write a file that does not parse
  if (( cch )) && ! lint_ok "$tmp/Content.qml"; then bad "Patched Content.qml failed the syntax check - NOT written"; rm -rf "$tmp"; return 1; fi
  if (( wch )) && ! lint_ok "$tmp/ContentWindow.qml"; then bad "Patched ContentWindow.qml failed the syntax check - NOT written"; rm -rf "$tmp"; return 1; fi
  [[ -n "$QMLLINT" ]] && ok "Patched files pass the QML syntax check" || info "No Qt 6 qmllint: patched files not syntax-checked"

  printf '\n  The following edits will be made (everything is inside marked blocks):\n'
  (( cch )) && { printf '  --- modules/dashboard/Content.qml (%s)\n' "${cs#STATUS }"; diff -u "$CONTENT" "$tmp/Content.qml" | sed -n '3,80p' | sed 's/^/      /'; }
  (( wch )) && { printf '  --- modules/drawers/ContentWindow.qml\n'; diff -u "$WIN" "$tmp/ContentWindow.qml" | sed -n '3,40p' | sed 's/^/      /'; }
  (( wch )) && info "Side effect: while the dashboard is open it can take keyboard focus when clicked (needed for typing)."
  confirm "Apply these edits to your Caelestia files?" || { info "Aborted. No Caelestia file was changed."; rm -rf "$tmp"; return 1; }

  [[ -n "$BACKUP_DIR" ]] || BACKUP_DIR="$CACHE/backups/$STAMP"
  mkdir -p "$BACKUP_DIR/files/modules/dashboard" "$BACKUP_DIR/files/modules/drawers" || { bad "Cannot create backup dir"; rm -rf "$tmp"; return 1; }
  local c_rel=modules/dashboard/Content.qml w_rel=modules/drawers/ContentWindow.qml
  cp -p "$CONTENT" "$BACKUP_DIR/files/$c_rel" && cp -p "$WIN" "$BACKUP_DIR/files/$w_rel" 2>/dev/null
  ok "Originals backed up to $BACKUP_DIR"

  restore_both() { warn "Restoring original Caelestia files"; $PRIV cp -p "$BACKUP_DIR/files/$c_rel" "$CONTENT"; [[ -f "$BACKUP_DIR/files/$w_rel" ]] && $PRIV cp -p "$BACKUP_DIR/files/$w_rel" "$WIN"; $PRIV rm -f "$CONTENT.cn-tmp" "$WIN.cn-tmp" 2>/dev/null; }
  if (( cch )) && ! { write_priv "$tmp/Content.qml" "$CONTENT"; } 2>/dev/null; then bad "Could not write Content.qml"; restore_both; rm -rf "$tmp"; return 1; fi
  if (( wch )) && ! { write_priv "$tmp/ContentWindow.qml" "$WIN"; } 2>/dev/null; then bad "Could not write ContentWindow.qml"; restore_both; rm -rf "$tmp"; return 1; fi
  if (( cch )) && ! cmp -s "$tmp/Content.qml" "$CONTENT"; then bad "Verification of Content.qml failed"; restore_both; rm -rf "$tmp"; return 1; fi
  if (( wch )) && ! cmp -s "$tmp/ContentWindow.qml" "$WIN"; then bad "Verification of ContentWindow.qml failed"; restore_both; rm -rf "$tmp"; return 1; fi
  (( cch )) && ok "Content.qml: Notes tab registered with a failure-safe loader"
  (( wch )) && ok "ContentWindow.qml: dashboard can take keyboard focus"
  rm -rf "$tmp"
  write_manifest || return 1
  printf '\n'
  info "Quickshell reloads on file changes, so the tab should appear within a moment."
  info "Quickshell keeps the previous working config if a reload fails. Undo anytime: install.sh --uninstall"
}

stage3_unregister() {   # remove our marked blocks (used by --uninstall)
  local f kind out tmp bk
  tmp="$(mktemp -d)"; bk="$CACHE/backups/$STAMP-uninstall/files"
  for f in modules/dashboard/Content.qml modules/drawers/ContentWindow.qml; do
    [[ -f "$SHELL_DIR/$f" ]] && grep -q '>>> caelestia-notes' "$SHELL_DIR/$f" || continue
    have python3 || { bad "python3 is needed to unregister the tab safely; nothing was removed"; rm -rf "$tmp"; return 1; }
    kind=content; [[ "$f" == *ContentWindow.qml ]] && kind=window
    out="$(cn_patch "$kind" remove "$SHELL_DIR/$f" "$tmp/$(basename "$f")")" || { bad "Cannot remove the managed block from $f: ${out#ERROR }"; rm -rf "$tmp"; return 1; }
    find_qmllint
    lint_ok "$tmp/$(basename "$f")" || { bad "Result for $f failed the syntax check - not written"; rm -rf "$tmp"; return 1; }
    mkdir -p "$bk/$(dirname "$f")" && cp -p "$SHELL_DIR/$f" "$bk/$f"
    write_priv "$tmp/$(basename "$f")" "$SHELL_DIR/$f" 2>/dev/null || { bad "Could not write $f"; rm -rf "$tmp"; return 1; }
    if grep -q '>>> caelestia-notes' "$SHELL_DIR/$f"; then bad "Managed block still present in $f"; rm -rf "$tmp"; return 1; fi
    ok "Restored $f (marked block removed)"
  done
  rm -rf "$tmp"
}

# --------------------------------------------------------------- summary ----
summary() {
  step "Result"
  printf '  %s checks passed, %s warnings, %s failures\n' "$PASS" "$WARNS" "$FAILS"
  local i p
  if (( ${#PLAN2[@]} )); then
    if [[ "$MODE" == install ]]; then printf '\n  Stage 2 - about to do:\n'; else printf '\n  Stage 2 - would do with --install:\n'; fi
    i=1; for p in "${PLAN2[@]}"; do printf '    %d. %s\n' "$i" "$p"; i=$((i+1)); done
  fi
  if (( ${#PLAN3[@]} )); then
    if (( NO_REGISTER )); then printf '\n  Stage 3 - skipped (--no-register); would otherwise edit Caelestia files:\n'
    elif [[ "$MODE" == install ]]; then printf '\n  Stage 3 - about to edit these Caelestia files (marked, reversible, backed up):\n'
    else printf '\n  Stage 3 - would do with --install (edits Caelestia files; marked, reversible, backed up):\n'; fi
    i=1; for p in "${PLAN3[@]}"; do printf '    %d. %s\n' "$i" "$p"; i=$((i+1)); done
  fi
  printf '\n'
  if (( FAILS > 0 )); then
    printf '  %sBLOCKED%s - fix the [FAIL] items above first. Nothing was modified.\n' "$(c '1;31')" "$(r)"; return 1
  elif (( WARNS > 0 )); then printf '  %sREADY WITH WARNINGS%s - review the [WARN] items above.\n' "$(c '1;33')" "$(r)"
  else printf '  %sREADY%s - everything checks out.\n' "$(c '1;32')" "$(r)"; fi
  [[ "$MODE" == check ]] && printf '  Nothing in your shell was modified (check mode is read-only). Add --install to install.\n'
  return 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install) MODE=install; shift;;
      --uninstall) MODE=uninstall; shift;;
      -y|--yes) ASSUME_YES=1; shift;;
      --force) FORCE=1; shift;;
      --no-register) NO_REGISTER=1; shift;;
      --no-keyboard) NO_KEYBOARD=1; shift;;
      --repo) REPO_URL="$2"; shift 2;;
      --branch) BRANCH="$2"; shift 2;;
      --no-color) USE_COLOR=0; shift;;
      -h|--help) usage;;
      *) printf 'Unknown option: %s\n' "$1" >&2; exit 2;;
    esac
  done
  printf '%sCaelestia Notes installer - mode: %s%s\n' "$(c '1;36')" "$MODE" "$(r)"
  if [[ "$MODE" == uninstall ]]; then
    step_preflight
    (( FAILS == 0 )) || { summary; exit 1; }
    stage2_uninstall || exit 1; exit 0
  fi
  step_preflight
  step_locate_shell
  step_shell_version
  step_dependencies
  step_fetch_payload
  step_verify_payload
  step_analyze_targets
  summary || exit 1
  if [[ "$MODE" == install ]]; then
    stage2_install || exit 1
    stage3_register || exit 1
  fi
}

# Everything is inside functions and main runs last, so a truncated
# `curl | bash` download can never execute a half-received script.
main "$@"
