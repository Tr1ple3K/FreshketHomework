# freshkettest

1. Installing bun in powershell

    iex "& {$(irm https://bun.sh/install.ps1)} -Version 1.1.6"

2. first running api server

    cd .\api-server-0.1.0\
    bun run index.ts

3. running application

    #Navigate to the API server directory:
    cd .\freshkettest\

    #Fetch the required Flutter dependencies:
    flutter pub get

    flutter run




