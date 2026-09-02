# @prompt: Mode for .npa files? (numbers / binary / mix)
import cleanedit

mode = (cleanedit.get_arg() or "numbers").strip().lower()
if mode not in ("numbers", "binary", "mix"):
    mode = "numbers"

cleanedit.set_mode(mode)
cleanedit.log("NPA data mode -> " + mode)
