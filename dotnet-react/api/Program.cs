var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// The one endpoint the front end calls.
app.MapGet("/api/hello", () => Results.Ok(new { message = "Hello from the .NET API!" }));

// Two-process model: serve only the API, bound to 0.0.0.0 on PORT (default 3001).
// The front-end dev server proxies /api here.
var port = Environment.GetEnvironmentVariable("PORT") ?? "3001";
app.Run($"http://0.0.0.0:{port}");
