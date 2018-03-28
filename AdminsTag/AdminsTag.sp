#include <sourcemod>
#include <cstrike>

public Plugin:myinfo =
{
        name = "Admins Tag",
        description = "Give admins tab tag",
        author = "PSIHoZ",
        version = "1.0.1",
        url = "https://github.com/0RaKlE19/csgo"
};


public OnPluginStart()
{
        HookEvent("player_team", Event1, EventHookMode:1);
        HookEvent("player_spawn", Event1, EventHookMode:1);
}

public OnClientPutInServer(client)
{
        HandleTag(client);
}

public Action:Event1(Handle:event, String:name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        if (0 < client)
        {
                HandleTag(client);
        }
        return Plugin_Continue;
}

HandleTag(client)

{
    if (GetUserFlagBits(client) & ADMFLAG_CUSTOM1)
    {
        CS_SetClientClanTag(client, "[TECH.ADMIN]");
    }
    else
		if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
        {
            CS_SetClientClanTag(client, "[HeadAdmin]");
        }
        else
            if (GetUserFlagBits(client) & ADMFLAG_ROOT)
			{
				CS_SetClientClanTag(client, "[CREATOR]");
			}
            else
                if (GetUserFlagBits(client) & ADMFLAG_UNBAN)
                {
                    CS_SetClientClanTag(client, "[SuperAdmin]");
                }
                else
                    if (GetUserFlagBits(client) & ADMFLAG_GENERIC)
                    {
						CS_SetClientClanTag(client, "[Admin]");
					}
					else
						if (GetUserFlagBits(client) & ADMFLAG_CUSTOM6)
						{
							CS_SetClientClanTag(client, "[DONATOR]");
						}
}