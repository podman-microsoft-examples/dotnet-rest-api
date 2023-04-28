FROM mcr.microsoft.com/dotnet/sdk:7.0 as build

# Copy csproj and restore as distinct layers 
WORKDIR /source
COPY *.csproj .
RUN dotnet restore --use-current-runtime

# Copy the rest of the project and build binaries 
COPY . .
RUN dotnet publish -c Release -o /app --os linux --arch x64 --no-cache

# Define the runtime container 
FROM mcr.microsoft.com/dotnet/aspnet:7.0 

# Install cURL to test the REST API
RUN apt-get update -yq \
    && apt-get install curl -yq

WORKDIR /app

# Copy binary to app
COPY --from=build /app .

# Define runtime parameters 
EXPOSE 80
ENV ASPNETCORE_ENVIRONMENT=Development

# start the app! 
ENTRYPOINT ["dotnet", "WeatherAPI.dll"]