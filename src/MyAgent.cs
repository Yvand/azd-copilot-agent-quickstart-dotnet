// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Microsoft.Agents.Builder;
using Microsoft.Agents.Builder.App;
using Microsoft.Agents.Builder.State;
using Microsoft.Agents.Core.Models;
using System.Threading.Tasks;
using System.Threading;
using Microsoft.Extensions.Logging;
using System;

namespace QuickStart;

public class MyAgent : AgentApplication
{
    private readonly ILogger<MyAgent> _logger;
    public MyAgent(AgentApplicationOptions options, ILogger<MyAgent> logger) : base(options)
    {
        _logger = logger;
        OnConversationUpdate(ConversationUpdateEvents.MembersAdded, WelcomeMessageAsync);
        OnActivity(ActivityTypes.Message, OnMessageAsync, rank: RouteRank.Last);
    }

    private async Task WelcomeMessageAsync(ITurnContext turnContext, ITurnState turnState, CancellationToken cancellationToken)
    {
        _logger.LogInformation("YVAND WelcomeMessageAsync visited at {DT}", DateTime.UtcNow.ToLongTimeString());
        foreach (ChannelAccount member in turnContext.Activity.MembersAdded)
        {
            if (member.Id != turnContext.Activity.Recipient.Id)
            {
                _logger.LogInformation("YVAND WelcomeMessageAsync Hello and Welcome! {DT}", DateTime.UtcNow.ToLongTimeString());
                await turnContext.SendActivityAsync(MessageFactory.Text("Hello and Welcome!"), cancellationToken);
            }
        }
    }

    private async Task OnMessageAsync(ITurnContext turnContext, ITurnState turnState, CancellationToken cancellationToken)
    {
        _logger.LogInformation($"YVAND OnMessageAsync text: {turnContext.Activity.Text}");
        await turnContext.SendActivityAsync($"You said: {turnContext.Activity.Text}", cancellationToken: cancellationToken);
    }
}
