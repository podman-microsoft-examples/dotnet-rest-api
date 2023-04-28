## Podman on Windows 11 

#### Overview 

This project is a quick example of using Podman on your Windows machine as an alternative to Docker. 

This project is a containerised deployment of the OOTB ASP.NET Example generated using the `$ dotnet new webapi -o WeatherAPI`

The goals of this project is to containerise the application, ensure we can buld on a Windows machine successfully and test the deployment. 

#### Pre-Reqs

##### Windows Terminal (Optional)

 It is also recommended to install the modern "Windows Terminal," which provides a superior user experience to the standard PowerShell and CMD prompts, as well as a WSL prompt, should you want it.

 You can install it by searching the Windows Store or by running the following winget command:

```bash 
$ winget install Microsoft.WindowsTerminal
``` 

> **NOTE** to install Podman Desktop: `$ winget install RedHat.Podman-Desktop`

##### Podman

Podman comes in 2 flavors. There is the Podman CLI which can be used to run, build and manage [OCI](https://opencontainers.org/) containers and container images. 

Podman desktop as you'd image provides the graphical tooling ontop of Podman to provide that seamless experience. Podman Desktop is optional, and wont be covered in this project.     

Podman can be installed in a number of ways, you can goto the [Podman GitHub Release Page](https://github.com/containers/podman/releases) and download the latest `podman-<RELEASE>-setup.exe`

Alternatively to install via the CLI using winget: 

`$ winget install Redhat.Podman`

##### Dotnet

The Dotnet CLI is used to buld and test the application locally. If you only want to test containerisation and buld the app via a multi-stage containerfile then the DotNet CLI is not required. 

```bash
$ winget install Microsoft.DotNet.SDK.7
```

### Running Code Locally (Not Containerised)

The DotNet CLI makes it easy to build, run and test dotnet applications. To test this app locally simply run: 

```bash
$ git clone <THIS_REPO>
$ cd WeatherAPI
$ $ dotnet run
Building...
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5129
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Development
info: Microsoft.Hosting.Lifetime[0]
      Content root path: C:\Users\ally_\Documents\DotNet\WeatherAPI
```

Then to test we can use cURL or jump on a browser and head to swagger: 

##### cURL  
```bash
$ curl http://localhost:5129/WeatherForecast                                                                        

StatusCode        : 200
StatusDescription : OK
Content           : [{"date":"2023-04-29","temperatureC":2,"temperatureF":35,"summary":"Chilly"},{"date":"2023-04-30","temperatureC"
                    :4,"temperatureF":39,"summary":"Sweltering"},{"date":"2023-05-01","temperatureC":-4,"tem...
RawContent        : HTTP/1.1 200 OK
                    Transfer-Encoding: chunked
                    Content-Type: application/json; charset=utf-8
                    Date: Fri, 28 Apr 2023 13:23:42 GMT
                    Server: Kestrel

                    [{"date":"2023-04-29","temperatureC":2,"temperatureF...
Forms             : {}
Headers           : {[Transfer-Encoding, chunked], [Content-Type, application/json; charset=utf-8], [Date, Fri, 28 Apr 2023
                    13:23:42 GMT], [Server, Kestrel]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : System.__ComObject
RawContentLength  : 390
```

##### Browser 

1. Open your browser of choice e.g. Google Chrome, FireFox, Edge (👀)... 

2. Navigate to: http://localhost:5129/swagger
    
3. You should see a screen like so: 

![something](/images/swagger-weather.png)

> **NOTE** Swagger is a graphical UI to help explore REST APIs. You can find out more at the [swagger](https://swagger.io/) website

4. Hit the `GET /WeatherForecast` dropdown > Hit `Try It Out` > `Execute`

You should see the returned JSON response in the `Server Response` section. 

### Running as a Container 

Now lets skip to the good bit... containers 🎉🎉🎉

##### Containerfile  

Podman pretty much mirrors Docker commands and capabilities. First of all checkout the `Containerfile` and have a look and the multi-stage container build, its broken down into 2 stages: 

1. Firstly, we import our source code into the MS DotNet SDK7 image, specifically into the `/source` folder. At which point we `dotnet restore` (download dependencies) and then build/publish our application for a linux based architecture. 

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:7.0 as build

# Copy csproj and restore as distinct layers 
WORKDIR /source
COPY *.csproj .
RUN dotnet restore --use-current-runtime

# Copy the rest of the project and build binaries 
COPY . .
RUN dotnet publish -c Release -o /app --os linux --arch x64 --no-cache
```

2. The second part of our `Containerfile` takes the compiled dotnet bianries and places these into our runtime container image (MS ASPNET7) under the `/app` folder. We install cURL for testing purposes and expose port 80, which is the default port for the published binary. Finally we start the application by executing the compiled `WeatherAPI.dll` file 

```dockerfile
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
```
> **_NOTE_** We use the ENV variable `ASPNETCORE_ENVIRONMENT=Development` to load the Development profile in our app. This ensures Swagger loads up, which typically wouldnt be available in a production profile. 

##### Building the Container Image

Building the container image from our Containerfile is very straight forward and identical to the process in Docker: 

```bash
$ podman build -t weather_api:v1 . 
[1/2] STEP 1/6: FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
...
[1/2] STEP 2/6: WORKDIR /source
...
[1/2] STEP 3/6: COPY *.csproj .
...
[1/2] STEP 4/6: RUN dotnet restore --use-current-runtime
...
[1/2] STEP 5/6: COPY . .
...
[1/2] STEP 6/6: RUN dotnet publish -c Release -o /app --os linux --arch x64 --no-cache
...
[2/2] STEP 1/7: FROM mcr.microsoft.com/dotnet/aspnet:7.0
[2/2] STEP 2/7: RUN apt-get update -yq && apt-get install curl -yq
...
[2/2] STEP 3/7: WORKDIR /app
...
[2/2] STEP 4/7: COPY --from=build /app .
...
[2/2] STEP 5/7: EXPOSE 80
...
[2/2] STEP 6/7: ENV ASPNETCORE_ENVIRONMENT=Development
...
[2/2] STEP 7/7: ENTRYPOINT ["dotnet", "WeatherAPI.dll"]
...
[2/2] COMMIT weather-api:v1
...
Successfully tagged localhost/weather-api:v1
Successfully tagged localhost/dotnet-weather:v1
13bb081833051ea03042aa9ea84f9e556a454ba31a5502c188bed56d466b6f2a
```

As you can see, like Docker, Podman will sequentially go through each build step, so should there be any issues its easy to identify where in the image build is the problem. 

You can then list the built image like so: 

```bash
 podman image ls
REPOSITORY                TAG         IMAGE ID      CREATED       SIZE
<none>                    <none>      ee20d2f87a1b  25 hours ago  261 MB
localhost/weather-api     v1          13bb08183305  2 days ago    243 MB
localhost/dotnet-weather  v1          13bb08183305  2 days ago    243 MB
localhost/dotnet-test     v1          b54993978472  2 days ago    319 MB
localhost/httpd-basic     latest      889b45daf917  2 weeks ago   245 MB
```

##### Running the Container Image

Now we have successfully built the image, we want to test it:

```bash
$ podman run -d --name weather-api -p 8080:80 weather-api:v1
5e66325e3618ea8a15f1cb22b8dc4509c436629299c19d90a060b75eb87299ad
```
`-d` tells Podman to run the container as a background process 

`--name` indicates the desired container name 

`-p` specified our port mappings from the internal container networking to our localhost. In this instance we map port 8080 to the containers port 80. 

We can view the running containers by listing them: 

```bash
$ podman container ls
CONTAINER ID  IMAGE                     COMMAND     CREATED         STATUS         PORTS                 NAMES
5e66325e3618  localhost/weather-api:v1              17 seconds ago  Up 18 seconds  0.0.0.0:8080->80/tcp  weather-api
```

##### Testing the Container Image

Testing is almost identical to the testing performed above, and again b/c we've mapped port 8080 to port 80 on the container we can use the browser. 

###### cURL (On Localhost)

```bash
curl http://localhost:8080/WeatherForecast


StatusCode        : 200
StatusDescription : OK
Content           : [{"date":"2023-04-29","temperatureC":-5,"temperatureF":24,"summary":"Freezing"},{"date":"2023-04-30","temperatur
                    eC":4,"temperatureF":39,"summary":"Hot"},{"date":"2023-05-01","temperatureC":42,"tempera...
RawContent        : HTTP/1.1 200 OK
                    Transfer-Encoding: chunked
                    Content-Type: application/json; charset=utf-8
                    Date: Fri, 28 Apr 2023 17:22:47 GMT
                    Server: Kestrel

                    [{"date":"2023-04-29","temperatureC":-5,"temperature...
Forms             : {}
Headers           : {[Transfer-Encoding, chunked], [Content-Type, application/json; charset=utf-8], [Date, Fri, 28 Apr 2023
                    17:22:47 GMT], [Server, Kestrel]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : System.__ComObject
RawContentLength  : 389
```

###### cURL (On Container)

Since we installed cURL via our Containerfile, we can also fire a cURL request from within the Container itself: 

```bash
$ podman exec weather-api curl -s http://weather-api/WeatherForecast

[{"date":"2023-04-29","temperatureC":-1,"temperatureF":31,"summary":"Cool"},{"date":"2023-04-30","temperatureC":-20,"temperatureF":-3,"summary":"Scorching"},{"date":"2023-05-01","temperatureC":3,"temperatureF":37,"summary":"Freezing"},{"date":"2023-05-02","temperatureC":45,"temperatureF":112,"summary":"Hot"},{"date":"2023-05-03","temperatureC":-18,"temperatureF":0,"summary":"Warm"}]
```

> **NOTE** Since Podman uses the container name as its host name we can use `weather-api` in our cURL request. We could have also used `localhost` . 

###### Browser

Finally to tie this example off, we can test Swagger via our chosen browser. Simply navigate to http://localhost:8080/swagger

![image](/images/swagger-weather-container.png)

#### Cleanup

To go full circle here are some commands to help shutdown and cleanup after the activities above: 

- Shutdown Container: `$ podman container shutdown weather-api`

- Delete Remove: `$ podman container rm weather-api `
- Force Shutdown and Delete: `$ podman container rm -f weather-api`
- Delete Container Image: `$ podman image rm weather-api`
- Delete any leftover artiburary images: `$ podman image prune --all`
