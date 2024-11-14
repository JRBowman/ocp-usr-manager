#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src
COPY ["Usr.Service.csproj", "."]
RUN dotnet restore "./Usr.Service.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "Usr.Service.csproj" -c Release -o /app/build

FROM build AS publish
RUN sudo apt-get -y update && sudo apt-get -y install apache2-utils
RUN dotnet publish "Usr.Service.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Usr.Service.dll"]