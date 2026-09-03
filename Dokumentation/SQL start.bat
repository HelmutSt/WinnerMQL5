@echo off
cd /d "%APPDATA%\MetaQuotes\Terminal\Common\Files"
start "" "c:\sqlite\sqlite3.exe" -cmd ".headers on" -cmd ".mode column" -cmd "SELECT name FROM sqlite_master WHERE type='table';" fdax.db