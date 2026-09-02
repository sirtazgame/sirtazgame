import cleanedit
import datetime

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
cleanedit.insert(now)
cleanedit.log("Inserted current date/time.")
