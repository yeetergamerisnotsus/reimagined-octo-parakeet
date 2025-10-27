#!/usr/bin/env bash
# insult-spammer.sh
# Local-only animated terminal "insult" printer
# Safe: only prints to terminal, no network, no system changes.

# --- helpers ---
esc() { printf '\033[%sm' "$1"; }   # usage: esc "31"  -> set color
reset() { printf '\033[0m'; }

# Default settings
MAX_INDENT=40
SLEEP=0.08    # only used in echo mode to slow animation slightly

# Read inputs
read -rp "Enter the target NAME (e.g. Alice): " NAME
read -rp "Enter an ADJECTIVE (e.g. goofy): " ADJ

# Choose colour mode
echo "Colour mode options:"
echo "  1) single (choose one colour)"
echo "  2) rainbow (cycle colours)"
while true; do
  read -rp "Choose colour mode (1/2) [2]: " CMODE
  CMODE=${CMODE:-2}
  [[ "$CMODE" =~ ^[12]$ ]] && break
  echo "Please enter 1 or 2."
done

if [[ $CMODE -eq 1 ]]; then
  echo "Choose a single colour:"
  echo "  1) red  2) green  3) yellow  4) blue  5) magenta  6) cyan  7) white"
  while true; do
    read -rp "Colour number [1]: " CSEL
    CSEL=${CSEL:-1}
    if [[ "$CSEL" =~ ^[1-7]$ ]]; then break; fi
    echo "Pick 1-7."
  done
  # map to ANSI codes (bright)
  case $CSEL in
    1) COLOUR_CODE="31";;
    2) COLOUR_CODE="32";;
    3) COLOUR_CODE="33";;
    4) COLOUR_CODE="34";;
    5) COLOUR_CODE="35";;
    6) COLOUR_CODE="36";;
    7) COLOUR_CODE="37";;
  esac
else
  # rainbow palette (cycle)
  RAINBOW_CODES=(31 33 32 36 34 35)  # red,yellow,green,cyan,blue,magenta-ish
fi

# Choose pattern
echo "Pattern animations:"
echo "  1) wave     - smooth back-and-forth"
echo "  2) zigzag   - quick back-and-forth steps"
echo "  3) pyramid  - grow then shrink"
echo "  4) staircase- increasing indent then reset"
while true; do
  read -rp "Choose pattern (1-4) [1]: " PAT
  PAT=${PAT:-1}
  [[ "$PAT" =~ ^[1-4]$ ]] && break
  echo "Pick 1-4."
done

# Output method
echo "Output method:"
echo "  1) echo  (controlled printing, prettier animation, slower)"
echo "  2) yes   (very fast, continuous stream; still animated by indentation)"
while true; do
  read -rp "Choose output method (1/2) [1]: " METH
  METH=${METH:-1}
  [[ "$METH" =~ ^[12]$ ]] && break
  echo "Pick 1 or 2."
done

# Loop count or infinite
while true; do
  read -rp "Number of loops (enter 0 for infinite until Ctrl+C) [0]: " NLOOPS
  NLOOPS=${NLOOPS:-0}
  if [[ "$NLOOPS" =~ ^[0-9]+$ ]]; then break; fi
  echo "Enter a non-negative integer."
done

# Compose message (playful, non-hateful)
MESSAGE="Hey ${NAME}, you're ${ADJ}!"

# Confirm quick summary
echo
echo "Starting animation:"
echo "  message: $MESSAGE"
if [[ $CMODE -eq 1 ]]; then echo "  colour: single ($COLOUR_CODE)"; else echo "  colour: rainbow"; fi
case $PAT in
  1) echo "  pattern: wave";;
  2) echo "  pattern: zigzag";;
  3) echo "  pattern: pyramid";;
  4) echo "  pattern: staircase";;
esac
if [[ $METH -eq 1 ]]; then echo "  output: echo (slower, prettier)"; else echo "  output: yes (very fast)"; fi
if [[ $NLOOPS -eq 0 ]]; then echo "  loops: infinite (Ctrl+C to stop)"; else echo "  loops: $NLOOPS"; fi
echo

# Helper function to compute triangular/bounce index
# triangular(n, m) returns value from 0..m..0 repeating with period 2*m
triangular_index() {
  local n=$1 m=$2
  local t=$(( n % (2*m) ))
  if (( t > m )); then
    echo $(( 2*m - t ))
  else
    echo "$t"
  fi
}

# If using echo method: controlled loop in bash
if [[ $METH -eq 1 ]]; then
  frame=0
  if [[ $NLOOPS -eq 0 ]]; then
    # infinite
    while :; do
      # choose indent by pattern
      case $PAT in
        1) indent=$(triangular_index $frame $MAX_INDENT);;
        2) # zigzag: faster steps (use half max)
           step=$((MAX_INDENT/2))
           indent=$(triangular_index $frame $step);;
        3) # pyramid: go 0..max..0 slower (use half period)
           indent=$(triangular_index $frame $((MAX_INDENT/2)));;
        4) # staircase
           indent=$(( frame % (MAX_INDENT+1) ));;
      esac

      # pick colour
      if [[ $CMODE -eq 1 ]]; then
        col="$COLOUR_CODE"
      else
        idx=$(( frame % ${#RAINBOW_CODES[@]} ))
        col="${RAINBOW_CODES[$idx]}"
      fi

      # print with indentation and colour
      printf '\033[%sm' "$col"
      printf "%*s%s\n" "$indent" "" "$MESSAGE"
      printf '\033[0m'
      frame=$((frame+1))
      sleep "$SLEEP"
    done

  else
    # finite loops
    for (( f=0; f<NLOOPS; f++ )); do
      case $PAT in
        1) indent=$(triangular_index $f $MAX_INDENT);;
        2) step=$((MAX_INDENT/2)); indent=$(triangular_index $f $step);;
        3) indent=$(triangular_index $f $((MAX_INDENT/2)));;
        4) indent=$(( f % (MAX_INDENT+1) ));;
      esac
      if [[ $CMODE -eq 1 ]]; then
        col="$COLOUR_CODE"
      else
        idx=$(( f % ${#RAINBOW_CODES[@]} ))
        col="${RAINBOW_CODES[$idx]}"
      fi
      printf '\033[%sm' "$col"
      printf "%*s%s\n" "$indent" "" "$MESSAGE"
      printf '\033[0m'
      sleep "$SLEEP"
    done
  fi

else
  # METH == 2 -> yes mode
  # yes prints $MESSAGE endlessly and we pipe through awk to add indentation + colours.
  # Awk will compute indentation from the line number (NR) and pattern choice.
  # Note: yes-mode is very fast. Use Ctrl+C to stop.
  AWK_PATTERN='
  function tri(n,m){
    t = n % (2*m)
    if (t > m) return 2*m - t
    return t
  }
  {
    f = NR-1
    if (pat == 1) {
      indent = tri(f, max)
    } else if (pat == 2) {
      indent = tri(f, int(max/2))
    } else if (pat == 3) {
      indent = tri(f, int(max/2))
    } else if (pat == 4) {
      indent = f % (max+1)
    } else {
      indent = tri(f, max)
    }
    if (cmode == 1) {
      col = colcode
    } else {
      # cycle through rainbow array
      idx = (f % rlen) + 1
      col = rcols[idx]
    }
    esc = sprintf("\033[%sm", col)
    reset = "\033[0m"
    # print with indentation
    printf("%s%*s%s%s\n", esc, indent, "", $0, reset)
    fflush()
  }'

  # prepare awk variables
  if [[ $CMODE -eq 1 ]]; then
    # single colour
    awk -v pat="$PAT" -v max="$MAX_INDENT" -v cmode=1 -v colcode="$COLOUR_CODE" \
        -v rlen=6 -v rcols="31,33,32,36,34,35" \
        -F'\n' "BEGIN{split(rcols,a,\",\"); for(i in a) rcols[i]=a[i]} { $0 = \$0 }" \
        < <(yes "$MESSAGE") | awk -v pat="$PAT" -v max="$MAX_INDENT" -v cmode=1 -v colcode="$COLOUR_CODE" -v rlen=6 -v rcols="31,33,32,36,34,35" "$AWK_PATTERN"
  else
    # rainbow mode: pass rcols as individual items
    # We'll pass colours by setting rcols in awk's BEGIN
    yes "$MESSAGE" | awk -v pat="$PAT" -v max="$MAX_INDENT" -v cmode=2 -v rlen=6 -v rcols="31,33,32,36,34,35" "$AWK_PATTERN"
  fi
fi
