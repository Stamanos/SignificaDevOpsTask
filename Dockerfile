# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

COPY src/MyApp/MyApp.csproj ./src/MyApp/
RUN dotnet restore ./src/MyApp/MyApp.csproj

COPY src/MyApp/ ./src/MyApp/
RUN dotnet publish ./src/MyApp/MyApp.csproj -c Release -o /app/publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080

ENTRYPOINT ["dotnet", "MyApp.dll"]
