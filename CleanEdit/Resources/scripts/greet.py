# @prompt: What is your name?
import cleanedit

name = cleanedit.get_arg() or "world"
cleanedit.insert("Hello, " + name + "!")
cleanedit.log("Greeted " + name)
