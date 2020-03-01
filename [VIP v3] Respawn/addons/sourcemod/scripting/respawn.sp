#pragma semicolon 1

#include <sourcemod>
#include <vip_core>
#include <cstrike>
#include <sdktools_gamerules>

#define RESPAWN_CMD 		"sm_respawn"	//	Команда для возрождения
//	Режим работы sm_vip_respawn_min_alive:
//		0 - Живых в команде игрока
//		1 - Живых в команде противника игрока
//		2 - Живых в обеих командах
//		3 - Живых в команде противника игрока и столько же в вашей


public Plugin:myinfo =
{
	name = "[VIP] Respawn(CS:GO ONLY!)",
	author = "R1KO, (ReWork by PSIH)",
	version = "3.0.0",
	url = "https://github.com/0RaKlE19/csgo"
};
static const char g_sFeature[] = "Respawn";
static const char g_sFeatureOnMap[] = "RespawnMap";
static const char g_sFeatureAuto[] = "AutoRespawn";

new bool:g_bAutoRespawn[MAXPLAYERS+1];

new g_iClientRespawns[MAXPLAYERS+1];
new g_iClientRespawnsInRaund[MAXPLAYERS+1];
new Float:g_fDeathTime[MAXPLAYERS+1];

new bool:g_bEnabled;
new Float:g_fStartDuration;
new Float:g_fEndDuration;
new g_iMinAlive;
new g_iMinAliveMode;

new bool:g_bEnabledRespawn;

new Handle:g_hTimer;
new Handle:g_hAuthTrie;

public OnPluginStart()
{
	g_hAuthTrie = CreateTrie();

	new Handle:hCvar = CreateConVar("sm_vip_respawn_enable", "1", "Включен ли плагин (0 - Отключен, 1 - Включен)", 0, true, 0.0, true, 1.0);
	g_bEnabled = GetConVarBool(hCvar);
	HookConVarChange(hCvar, OnEnabledChange);
	
	hCvar = CreateConVar("sm_vip_respawn_start_duration", "20.0", "Через сколько секунд после начала раунда игрок может возрождаться (0.0 - Отключено)", 0, true, 0.0);
	HookConVarChange(hCvar, OnStartDurationChange);
	g_fStartDuration = GetConVarFloat(hCvar);
	
	hCvar = CreateConVar("sm_vip_respawn_end_duration", "120.0", "Сколько секунд после начала раунда игрок может возрождаться (0.0 - Отключено)", 0, true, 0.0);
	HookConVarChange(hCvar, OnEndDurationChange);
	g_fEndDuration = GetConVarFloat(hCvar);
	
	hCvar = CreateConVar("sm_vip_respawn_min_alive", "0", "Сколько минимально должно быть живых игроков в команде чтобы игрок мог возрождаться (0.0 - Отключено)", 0, true, 0.0);
	HookConVarChange(hCvar, OnMinAliveChange);
	g_iMinAlive = GetConVarInt(hCvar);
	
	hCvar = CreateConVar("sm_vip_respawn_min_alive_mode", "3", "Режим работы sm_vip_respawn_min_alive, N живых в:\n0 - команде игрока\n1 - команде противника\n2 - любой команде\n3 - команде противника и живых в команде противника больше чем в вашей", 0, true, 0.0);
	HookConVarChange(hCvar, OnMinAliveModeChange);
	g_iMinAliveMode = GetConVarInt(hCvar);
	
	
	AutoExecConfig(true, "VIP_Respawn", "vip");

	RegConsoleCmd(RESPAWN_CMD, Respawn_CMD);
	
	HookEventEx("round_freeze_end", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEventEx("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_death", Event_PlayerDeath);

	LoadTranslations("vip_respawn.phrases");
	LoadTranslations("vip_modules.phrases");
	LoadTranslations("vip_core.phrases");

	if(VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
}

public OnEnabledChange(Handle:hCvar, const String:oldValue[], const String:newValue[])	g_bEnabled = GetConVarBool(hCvar);
public OnStartDurationChange(Handle:hCvar, String:oldValue[], String:newValue[])		g_fStartDuration = GetConVarFloat(hCvar);
public OnEndDurationChange(Handle:hCvar, String:oldValue[], String:newValue[])			g_fEndDuration = GetConVarFloat(hCvar);
public OnMinAliveChange(Handle:hCvar, String:oldValue[], String:newValue[])				g_iMinAlive = GetConVarInt(hCvar);
public OnMinAliveModeChange(Handle:hCvar, String:oldValue[], String:newValue[]) 		g_iMinAliveMode = GetConVarInt(hCvar);

public VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature, INT, SELECTABLE, OnSelectItem, OnDisplayItem, OnDrawItem);
	VIP_RegisterFeature(g_sFeatureAuto, BOOL, TOGGLABLE, OnToggleItem);
	VIP_RegisterFeature(g_sFeatureOnMap, INT, HIDE);
}

public OnPluginEnd()
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_sFeature);
		VIP_UnregisterFeature(g_sFeatureAuto);
		VIP_UnregisterFeature(g_sFeatureOnMap);
	}
}

public OnMapStart()
{
		ClearTrie(g_hAuthTrie);
		for(new i = 1; i <= MaxClients; ++i) g_iClientRespawns[i] = 0;
}

public Action:Respawn_CMD(iClient, args)
{
	if(iClient)
	{
		if(!g_bEnabled)
		{
			VIP_PrintToChatClient(iClient, "%t", "RESPAWN_OFF");
		}
		if(VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, g_sFeature))
		{
			RespawnClient(iClient);
		}
		else
		{
			VIP_PrintToChatClient(iClient, "%t", "COMMAND_NO_ACCESS");
		}
	}
	return Plugin_Handled;
}

public Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	ClearTrie(g_hAuthTrie);
	for(new i = 1; i <= MaxClients; ++i) g_iClientRespawnsInRaund[i] = 0;

	if (g_hTimer != INVALID_HANDLE)
	{
		KillTimer(g_hTimer);
		g_hTimer = INVALID_HANDLE;
	}

	if(g_fStartDuration)
	{
		g_bEnabledRespawn = false;

		g_hTimer = CreateTimer(g_fStartDuration, Timer_EnableRespawn);

		return;
	}

	g_bEnabledRespawn = true;

	if (g_fEndDuration)
	{
		g_hTimer = CreateTimer(g_fEndDuration, Timer_DisableRespawn);
	}
}

public Action:Timer_EnableRespawn(Handle:hTimer)
{
	g_bEnabledRespawn = true;

	if(g_fEndDuration && g_fEndDuration > g_fStartDuration)
	{
		g_hTimer = CreateTimer(g_fEndDuration-g_fStartDuration, Timer_DisableRespawn);
		return Plugin_Stop;
	}

	g_hTimer = INVALID_HANDLE;

	return Plugin_Stop;
}

public Action:Timer_DisableRespawn(Handle:hTimer)
{
	g_bEnabledRespawn = false;
	g_hTimer = INVALID_HANDLE;

	return Plugin_Stop;
}

public Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabledRespawn)
	{
		g_bEnabledRespawn = false;
	}

	if (g_hTimer != INVALID_HANDLE)
	{
		KillTimer(g_hTimer);
		g_hTimer = INVALID_HANDLE;
	}
}

public OnClientPutInServer(iClient)
{
	g_iClientRespawns[iClient] = 0;
	
	decl String:sAuth[32];
	GetClientAuthId(iClient, AuthId_Engine, sAuth, sizeof(sAuth));
	GetTrieValue(g_hAuthTrie, sAuth, g_iClientRespawns[iClient]);
}

public Event_PlayerDeath(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	g_fDeathTime[iClient] = GetGameTime();
	
	if(g_bAutoRespawn[iClient])
	{
		CreateTimer(1.0, Timer_RespawnClient, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_RespawnClient(Handle:hTimer, any:iUserID)
{
	new iClient = GetClientOfUserId(iUserID);
	if(iClient && IsClientInGame(iClient) && CheckRespawn(iClient, false))
	{
		VIP_PrintToChatClient(iClient, "%t", "AUTORESPAWN_NOTIFY");
		RespawnClient(iClient, false);
	}

	return Plugin_Stop;
}

RespawnClient(iClient, bool:bCheck = true)
{
	if(bCheck && !CheckRespawn(iClient, true))
	{
		return;
	}

	++g_iClientRespawns[iClient];
	++g_iClientRespawnsInRaund[iClient];

	decl String:sAuth[32];
	GetClientAuthId(iClient, AuthId_Engine, sAuth, sizeof(sAuth));
	SetTrieValue(g_hAuthTrie, sAuth, g_iClientRespawns[iClient]);

	CS_RespawnPlayer(iClient);
}

bool:CheckRespawn(iClient, bool:bNotify, bool:bFromMenu = false)
{
	if(!g_bEnabled)
	{
		VIP_PrintToChatClient(iClient, "%t", "RESPAWN_OFF");
		return false;
	}
	if(!g_bEnabledRespawn)
	{
		if(bNotify)
		{
			VIP_PrintToChatClient(iClient, "%t", "RESPAWN_FORBIDDEN");
		}
		return false;
	}

	if(GetEngineVersion() == Engine_CSGO && GameRules_GetProp("m_bWarmupPeriod") == 1) 
    {
		if(bNotify)
		{
			VIP_PrintToChatClient(iClient, "%t", "RESPAWN_FORBIDDEN_ON_WARMUP");
		}
		return false;
	}

	if(GetGameTime() < g_fDeathTime[iClient] + 1.0)
	{
		return false;
	}

	new iClientTeam = GetClientTeam(iClient);
	if(iClientTeam < 2)
	{
		if(bNotify)
		{
			VIP_PrintToChatClient(iClient, "%t", "YOU_MUST_BE_ON_TEAM");
		}
		return false;
	}

	if(!bFromMenu && IsPlayerAlive(iClient))
	{
		if(bNotify)
		{
			VIP_PrintToChatClient(iClient, "%t", "YOU_MUST_BE_DEAD");
		}
		return false;
	}

	new iROM = VIP_GetClientFeatureInt(iClient, g_sFeatureOnMap) - g_iClientRespawns[iClient];
	new iRIR = VIP_GetClientFeatureInt(iClient, g_sFeature) - g_iClientRespawnsInRaund[iClient];

	if(iRIR <= 0 || iROM <=0)
	{
		if(bNotify)
		{
			if(iRIR<=0 && iROM != 0)	VIP_PrintToChatClient(iClient, "%t", "REACHED_ROUND_LIMIT");
			else	VIP_PrintToChatClient(iClient, "%t", "REACHED_MAP_LIMIT");
		}
		return false;
	}
	
	if(!bFromMenu && g_iMinAlive)
	{
		decl iPlayers[2], i, iTeam;
		iPlayers[0] = iPlayers[1] = 0;
		for(i = 1; i <= MaxClients; ++i)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && (iTeam = GetClientTeam(i)) > 1)
			{
				++iPlayers[iTeam-2];
			}
		}
		if(g_iMinAliveMode == 0) // В команде игрока
		{
			if(iPlayers[iClientTeam == 2 ? 0:1] < g_iMinAlive)
			{
				if(bNotify)
				{
					VIP_PrintToChatClient(iClient, "%t", "NOT_ENOUGH_ALIVE_PLAYERS_TEAM");
				}
				return false;
			}
		}
		if(g_iMinAliveMode == 1) // В команде противника
		{
			if(iPlayers[iClientTeam == 2 ? 1:0] < g_iMinAlive)
			{
				if(bNotify)
				{
					VIP_PrintToChatClient(iClient, "%t", "NOT_ENOUGH_ALIVE_PLAYERS_NOT_TEAM");
				}
				return false;
			}
		}
		if(g_iMinAliveMode == 2) // В любой команде
		{
			if(iPlayers[0] < g_iMinAlive || iPlayers[1] < g_iMinAlive)
			{
				if(bNotify)
				{
					VIP_PrintToChatClient(iClient, "%t", "NOT_ENOUGH_ALIVE_PLAYERS");
				}
				return false;
			}
		}
		if(g_iMinAliveMode == 3) // В команде противника и в моей < противника
		{
			if(iPlayers[iClientTeam == 2 ? 1:0] < g_iMinAlive)
			{
				if(bNotify)
				{
					VIP_PrintToChatClient(iClient, "%t", "NOT_ENOUGH_ALIVE_PLAYERS_NOT_TEAM");
				}
				return false;
			}
			if(iPlayers[iClientTeam == 2 ? 0:1] >= iPlayers[iClientTeam == 2 ? 1:0])
			{
				if(bNotify)
				{
					VIP_PrintToChatClient(iClient, "%t", "TO_MORE_ALIVE_PLAYERS_IN_TEAM");
				}
				return false;
			}
		}
	}
	return true;
}

public bool:OnSelectItem(iClient, const String:sFeatureName[])
{
	RespawnClient(iClient);
	return true;
}

public bool:OnDisplayItem(iClient, const String:sFeatureName[], String:sDisplay[], maxlen)
{
	if(VIP_GetClientFeatureStatus(iClient, g_sFeature) == ENABLED)
	{
		new iRIR = VIP_GetClientFeatureInt(iClient, g_sFeature) - g_iClientRespawnsInRaund[iClient];
		new iROM = VIP_GetClientFeatureInt(iClient, g_sFeatureOnMap) - g_iClientRespawns[iClient];
		if(iRIR != -1)
		{
			if(iROM <=0 || iROM <= iRIR)	iRIR = iROM;
			FormatEx(sDisplay, maxlen, "%T [%T]", g_sFeature, iClient, "Left", iClient, iRIR);
			return true;
		}
	}
	return false;
}

public OnDrawItem(iClient, const String:sFeatureName[], iStyle)
{
	if(VIP_GetClientFeatureStatus(iClient, g_sFeature) != NO_ACCESS)
	{
		if(!g_bEnabled)
		{
			return ITEMDRAW_DISABLED;
		}

		if(!CheckRespawn(iClient, false, true))
		{
			return ITEMDRAW_DISABLED;
		}
	}

	return iStyle;
}

public Action:OnToggleItem(iClient, const String:sFeatureName[], VIP_ToggleState:OldStatus, &VIP_ToggleState:NewStatus)
{
	g_bAutoRespawn[iClient] = (NewStatus == ENABLED);

	return Plugin_Continue;
}