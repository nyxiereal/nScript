# nScript
A powershell script to clean up Windows 10/11 installations.

## Features
- Remove empty folders
- Remove files/folders that have not been accessed in 24 hours
- Removes browser profiles (Chrome, Edge, Firefox, Opera/GX)
- Optional force mode to delete files/folders regardless of access time
- Keeps some files intact (VirtualBox and ISO files)
- Displays drive information after the cleanup process

## Version comparison
| Type   | Features                                                        |
| ------ | --------------------------------------------------------------- |
| Manual | Manual execution, optional force mode                           |
| Task   | Designed to be executed automatically, with user type detection |