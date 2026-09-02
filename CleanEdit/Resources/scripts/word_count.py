import cleanedit

text = cleanedit.get_text()
words = len(text.split())
lines = text.count("\n") + 1 if text else 0
chars = len(text)

cleanedit.log("Words: %d | Lines: %d | Characters: %d" % (words, lines, chars))
