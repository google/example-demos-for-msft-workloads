# Use Microsoft's official lightweight .NET images.
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

# Install production dependencies.
# Copy csproj and restore as distinct layers.
COPY *.csproj ./
RUN dotnet restore

# Copy local code to the container image.
COPY . ./

# Build a release artifact.
RUN dotnet publish -c Release -o out

# Run the web service on container startup in a lean production image.
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/out .

# Start the .dll (will have the same name as your .csproj file)
ENTRYPOINT ["dotnet", "AspNetCoreWebApi6.dll"]