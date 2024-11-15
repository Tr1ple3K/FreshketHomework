# Freshket Homework
1. Installing bun in **Powershell**
    
    ```
    iex "& {$(irm https://bun.sh/install.ps1)} -Version 1.1.6"
    ```

1. Running API server

    1.1 Navigate to the API server directory
    ```
    cd .\api-server-0.1.0\
    ```

    1.2 Run the server
    ```
    bun run index.ts
    ```

3. Running application

    3.1 Fetch the required Flutter dependencies:
    ```
    flutter pub get
    ```

    3.2 Run the application
    ```
    flutter run
    ```




