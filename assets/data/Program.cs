using Grand.Infrastructure.Configuration;
using Grand.Web.Common.Startup;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
using StartupBase = Grand.Infrastructure.StartupBase;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseDefaultServiceProvider((_, options) =>
{
    options.ValidateScopes = false;
    options.ValidateOnBuild = false;
});

//use serilog
builder.Host.UseSerilog();

//add configuration
builder.Host.ConfigureAppConfiguration((hostingContext, config) =>
{
    config.SetBasePath(hostingContext.HostingEnvironment.ContentRootPath);
    config.AddJsonFile("App_Data/appsettings.json", optional: false, reloadOnChange: true);
    config.AddEnvironmentVariables();
    if (args != null)
    {
        config.AddCommandLine(args);
        var settings = config.Build();
        var appsettings = settings["appsettings"];
        var param = settings["Directory"];
        if (!string.IsNullOrEmpty(appsettings) && !string.IsNullOrEmpty(param))
            config.AddJsonFile($"App_Data/{param}/appsettings.json", optional: false, reloadOnChange: true);
    }

});

// Binds to all IPs (external, localhost, Docker, etc.)
builder.WebHost.UseUrls("https://0.0.0.0:5001");

// Prevent host shutdown on BackgroundService exception
builder.Services.Configure<HostOptions>(options =>
{
    options.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore;
});

//create logger
Log.Logger = new LoggerConfiguration().ReadFrom.Configuration(builder.Configuration).CreateLogger();

//add services
StartupBase.ConfigureServices(builder.Services, builder.Configuration);

//Allow non ASCII chars in headers
var config = new AppConfig();
builder.Configuration.GetSection("Application").Bind(config);
if (config.AllowNonAsciiCharInHeaders)
{
    builder.WebHost.ConfigureKestrel(options =>
    {
        options.ResponseHeaderEncodingSelector = _ => Encoding.UTF8;
    });
}
if (config.MaxRequestBodySize.HasValue)
{
    builder.WebHost.ConfigureKestrel(host =>
    {
        host.Limits.MaxRequestBodySize = config.MaxRequestBodySize.Value;
    });

    builder.Services.Configure<FormOptions>(opt =>
    {
        opt.MultipartBodyLengthLimit = config.MaxRequestBodySize.Value;
    });

}
//register task
builder.Services.RegisterTasks();

//build app
var app = builder.Build();

// Add middleware for logging requests and responses
app.Use(async (context, next) =>
{
    // Log Request Headers
    Log.Information("Request Headers: {@Headers}", context.Request.Headers);

    // Ensure the request body can be read multiple times
    context.Request.EnableBuffering();

    using (var reader = new StreamReader(context.Request.Body, Encoding.UTF8, leaveOpen: true))
    {
        var body = await reader.ReadToEndAsync();
        // Reset the request body stream position
        context.Request.Body.Position = 0;

        // Log Request Body (if not empty)
        if (!string.IsNullOrEmpty(body))
        {
            Log.Information("Request Body: {Body}", body);
        }
    }

    // Proceed to the next middleware
    await next(context);

    // Log Response Headers
    Log.Information("Response Headers: {@Headers}", context.Response.Headers);
});


//request pipeline
StartupBase.ConfigureRequestPipeline(app, builder.Environment);

//run app
app.Run();
