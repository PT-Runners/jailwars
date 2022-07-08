// Includes
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <myjailbreak>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

// Info
public Plugin myinfo = {
    name = "PTR - JailWars add",
    author = "Kamizun edited by Trayz",
    description = "Spawn gun and kev",
    version = "1.1",
    url = ""
};

// Start
public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn);
}

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    if(MyJailbreak_IsEventDayRunning() || GameRules_GetProp("m_bWarmupPeriod") == 1)
        return;

    int iMaxTries = 5;

    for(int i = 1; i <= iMaxTries; i++)
    {
        int client = GetRandomPlayerFromTeam(CS_TEAM_T);

        if (!IsValidClient(client, false, false))
            continue;

        GivePlayerItem(client, "weapon_fiveseven");
        CPrintToChat(client, "{green}> {default}Recebeste uma fiveseven.");
        break;
    }
}

public void Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    if(MyJailbreak_IsEventDayRunning() || GameRules_GetProp("m_bWarmupPeriod") == 1)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));

    if(!IsValidClient(client, false, false))
        return;

    if(GetClientTeam(client) != CS_TEAM_T)
        return;

    SetEntProp(client, Prop_Data, "m_ArmorValue", 50);
    CPrintToChat(client, "{green}> {default}Recebeste 50 armadura.");
}

stock bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}

stock int GetRandomPlayerFromTeam(int team)
{
    int clients[MAXPLAYERS + 1];
    int clientCount;
    for (int i = 1; i <= MaxClients; i++)
    if (IsClientInGame(i) && (GetClientTeam(i) == team))
        clients[clientCount++] = i;
    return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];
}  