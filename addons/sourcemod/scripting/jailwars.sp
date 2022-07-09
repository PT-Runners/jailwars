// Includes
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <myjailbreak>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

ConVar g_cvEnable;
ConVar g_cvPrisonersArmor;
ConVar g_cvRandomPrisonerWeapon;

char g_sRandomPrisonerWeapon[64];

// Info
public Plugin myinfo = {
    name = "PTR - JailWars add",
    author = "Kamizun edited by Trayz",
    description = "Spawn gun and kev",
    version = "1.3",
    url = ""
};

// Start
public void OnPluginStart()
{
    g_cvEnable = CreateConVar("sm_jailwars_enable", "1", "Enable jailwars.", _, true, 0.0, true, 1.0);
    g_cvPrisonersArmor = CreateConVar("sm_jailwars_prisoners_armor_value", "50", "Give armor prisoners on round start. 0 to disable", _, true, 0.0, true, 100.0);
    g_cvRandomPrisonerWeapon = CreateConVar("sm_jailwars_random_prisoner_weapon", "weapon_fiveseven", "Give weapon to random prisoner on round start. Empty to disable");
    g_cvRandomPrisonerWeapon.AddChangeHook(OnConVarChanged);

    AutoExecConfig();

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvRandomPrisonerWeapon)
        g_cvRandomPrisonerWeapon.GetString(g_sRandomPrisonerWeapon, sizeof(g_sRandomPrisonerWeapon));
}

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    if(!g_cvEnable.BoolValue)
        return;

    if(StrEqual(g_sRandomPrisonerWeapon, ""))
        return;

    if(MyJailbreak_IsEventDayRunning() || GameRules_GetProp("m_bWarmupPeriod") == 1)
        return;

    int iMaxTries = 5;

    for(int i = 1; i <= iMaxTries; i++)
    {
        int client = GetRandomPlayerFromTeam(CS_TEAM_T);

        if (!IsValidClient(client, false, false))
            continue;

        GivePlayerItem(client, g_sRandomPrisonerWeapon);

        char szWeaponName[64];
        strcopy(szWeaponName, sizeof(szWeaponName), g_sRandomPrisonerWeapon);
        ReplaceString(szWeaponName, sizeof(szWeaponName), "weapon_", "");

        CPrintToChat(client, "{green}> {default}Recebeste uma %s.", szWeaponName);
        break;
    }
}

public void Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    if(!g_cvEnable.BoolValue)
        return;

    if(!g_cvPrisonersArmor.IntValue)
        return;

    if(MyJailbreak_IsEventDayRunning() || GameRules_GetProp("m_bWarmupPeriod") == 1)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));

    if(!IsValidClient(client, false, false))
        return;

    if(GetClientTeam(client) != CS_TEAM_T)
        return;

    SetEntProp(client, Prop_Data, "m_ArmorValue", g_cvPrisonersArmor.IntValue);
    CPrintToChat(client, "{green}> {default}Recebeste %i armadura.", g_cvPrisonersArmor.IntValue);
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