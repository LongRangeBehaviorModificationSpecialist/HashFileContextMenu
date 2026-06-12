## HashFileContextMenu

### How to install and use

---

1. You can down the .zip file from the "Releases" section or clone the repository directly.

1. Open a PowerShell window as an Administrator.

1. Run the `Add_Get-FileHash_to_Context_Menu.ps1` file as administrator.

    - This will copy the three .ico files to the `%USERPROFILE%\Pictures\icons` directory (if the directory does not exist, it will be created).

    - The `files\Get-FileHashValue.ps1` file will be copied to the `%USERPROFILE%\Documents\WindowsPowerShell` directory (if the directory does not exist, it will be created).

1. The user will have the option to choose which hash algorithm to use (valid options are: `MD5`, `SHA1`, `SHA256`, and `SHA512`).

1. Then the user will be able to chose whether to view the results in the terminal window or to save the results to a text file.  The output file will be saved in the same directory as the file that was hashed and will begin with the same name as the file that was hashed.  The date and time that the file was hashed will be appended to the output file with the format `yyyy-MM-dd_HHmmss` in UTC time.  Finally, the file extension of the output file will be the name of the hashing algorithm that was selected.

    - For example, if the user selected to save the `SHA256` hash of the file named `README.md` that was in the `C:\Users\user\Desktop` directory, the output file would be named `README.md_yyyy-MM-dd_HHmmss.SHA256`.

1. The script will then edit the registry so that the files with extensions of `.MD5`, `.SHA1`, `.SHA256`, and `SHA512` will be associated with the Notepad++ application.

1. When the process is complete, a message box will appear indicating the name of the output file and the directory in which it has been saved.

1. The contents of the output file will be as follows:

```
[yyyy-mm-ddTHH:mm:ssZ] Hashing started for file: README.md


    File Name  :  README.md
    Directory  :  C:\Users\user\Documents
    File Size  :  296.82 KB (303,947 bytes)
    Hash       :  <SHA256 hash value>
    Algorithm  :  SHA256


[yyyy-mm-ddTHH:mm:ssZ] File hashing complete.
```

#### To-Do

---

1. Add ability for user to choose which text editor to associate with the new file extensions (e.g., Notepad++, Notepad, Wordpad, VSCode...).