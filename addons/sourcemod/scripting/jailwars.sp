// Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required


// Info
public Plugin myinfo = {
    name = "PTR - JailWars add",
    author = "Kamizun",
    description = "Spawn gun and kev",
    version = "1.0",
    url = ""
};

// Start
public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
}

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    int player = GetRandomPlayerFromTeam(CS_TEAM_T);
    if (!IsValidClient(player, false, false))
        return;

    GivePlayerItem(player, "weapon_fiveseven");
}

public void Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i, false, false))
        {
            return;
        }

        if (GetClientTeam(i) != CS_TEAM_T)
        {
            return;
        }

        SetEntProp(i, Prop_Data, "m_ArmorValue", 50);
    }
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