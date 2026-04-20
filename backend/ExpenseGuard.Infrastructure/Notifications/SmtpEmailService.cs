using ExpenseGuard.Domain.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Net;
using System.Net.Mail;

namespace ExpenseGuard.Infrastructure.Notifications;

public class SmtpEmailService : IEmailService
{
    private readonly string _host;
    private readonly int _port;
    private readonly string _user;
    private readonly string _pass;

    public SmtpEmailService(IConfiguration config)
    {
        _host = config["Smtp:Host"] ?? "smtp.mailtrap.io";
        _port = int.TryParse(config["Smtp:Port"], out var p) ? p : 2525;
        _user = config["Smtp:User"] ?? "mock_user";
        _pass = config["Smtp:Pass"] ?? "mock_pass";
    }

    public async Task SendEmailAsync(string to, string subject, string body, CancellationToken ct = default)
    {
        if (_user == "mock_user")
        {
            // Development ortamında gerçek mail atmayıp konsola bas
            Console.WriteLine($"[MOCK EMAIL] To: {to} | Subject: {subject}");
            Console.WriteLine(body);
            return;
        }

        using var client = new SmtpClient(_host, _port)
        {
            Credentials = new NetworkCredential(_user, _pass),
            EnableSsl = true
        };

        var message = new MailMessage
        {
            From = new MailAddress("noreply@expenseguard.com", "ExpenseGuard Pro"),
            Subject = subject,
            Body = body,
            IsBodyHtml = true
        };
        message.To.Add(to);

        await client.SendMailAsync(message, ct);
    }
}
