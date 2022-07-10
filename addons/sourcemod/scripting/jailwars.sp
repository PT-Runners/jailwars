// Includes
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <myjailbreak>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

#define GOD_ON 0
#define GOD_OFF 2

enum struct ScoreboardStats
{
    int iFrags;
    int iDeaths;
    int iMVPs;
    int iScore;
    int iAssists;
}

ScoreboardStats g_iScoreBoard[MAXPLAYERS + 1];

ConVar g_cvEnable;
ConVar g_cvPrisonersArmor;
ConVar g_cvRandomPrisonerWeapon;
ConVar g_cvLogEnable;
ConVar g_cvRoundDisqualifiedEndTime;

Handle g_hHUD;

float g_fHudPosX = -1.0;
float g_fHudPosY = 0.2;
float g_fHudUpdate = 5.0; 

char g_sRandomPrisonerWeapon[64];
char g_sFilePath[PLATFORM_MAX_PATH];

int g_iHudRgba[4] = { 139, 0, 0 , 255};
int g_iClientInChargeRoundDisqualified = -1;

// Info
public Plugin myinfo = {
    name = "PTR - JailWars add",
    author = "Kamizun edited by Trayz",
    description = "Spawn gun and kev",
    version = "1.4",
    url = ""
};

// Start
public void OnPluginStart()
{
    g_cvEnable = CreateConVar("sm_jailwars_enable", "1", "Enable jailwars.", _, true, 0.0, true, 1.0);
    g_cvPrisonersArmor = CreateConVar("sm_jailwars_prisoners_armor_value", "50", "Give armor prisoners on round start. 0 to disable", _, true, 0.0, true, 100.0);
    g_cvRandomPrisonerWeapon = CreateConVar("sm_jailwars_random_prisoner_weapon", "weapon_fiveseven", "Give weapon to random prisoner on round start. Empty to disable");
    g_cvRandomPrisonerWeapon.AddChangeHook(OnConVarChanged);

    g_cvLogEnable = CreateConVar("sm_jailwars_log_enable", "1", "Enable jailwars log.", _, true, 0.0, true, 1.0);
    g_cvRoundDisqualifiedEndTime = CreateConVar("sm_jailwars_round_disqualified_round_end_time", "5.0", "Time to wait to end round after desqualified", _, true, 0.0, true, 10.0);

    AutoExecConfig();

    g_hHUD = CreateHudSynchronizer();

    RegAdminCmd("sm_disqualify", Command_RoundDisqualified, ADMFLAG_BAN);
    RegAdminCmd("sm_desqualificar", Command_RoundDisqualified, ADMFLAG_BAN);

    RegAdminCmd("sm_swaprs", CMD_SwapRs, ADMFLAG_BAN, "Swap the targets team");

    LoadTranslations("jailwars.phrases");

    HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvRandomPrisonerWeapon)
        g_cvRandomPrisonerWeapon.GetString(g_sRandomPrisonerWeapon, sizeof(g_sRandomPrisonerWeapon));
}

public void OnConfigsExecuted()
{
    if(!g_cvEnable.BoolValue || !g_cvLogEnable.BoolValue)
        return;

    BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "logs/jailwars");
    
    if (!DirExists(g_sFilePath))
    {
        CreateDirectory(g_sFilePath, 511);
        
        if (!DirExists(g_sFilePath))
            SetFailState("Failed to create directory at /sourcemod/logs/jailwars - Please manually create that path and reload this plugin.");
    }

    char FormatedTime[100];
    char MapName[100];
        
    int CurrentTime = GetTime();
    
    GetCurrentMap(MapName, 100);
    FormatTime(FormatedTime, 100, "%d_%b_%Y_%H_%M_%S", CurrentTime); //name the file 'day month year'
    
    BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "/logs/jailwars/%s_%s.txt", FormatedTime, MapName);
}

public void Event_RoundPreStart(Handle event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i < MAXPLAYERS; i++)
    {
        if(!IsClientInGame(i))
            continue;
        
        g_iScoreBoard[i].iFrags = GetEntProp(i, Prop_Data, "m_iFrags");
        g_iScoreBoard[i].iDeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
        g_iScoreBoard[i].iMVPs = CS_GetMVPCount(i);
        g_iScoreBoard[i].iScore = CS_GetClientContributionScore(i);
        g_iScoreBoard[i].iAssists = CS_GetClientAssists(i);
    }
}

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    if(!g_cvEnable.BoolValue)
        return;

    g_iClientInChargeRoundDisqualified = -1;

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

public void OnClientPostAdminCheck(int client)
{
    if(!g_cvEnable.BoolValue)
        return;
        
    SDKHook(client, SDKHook_SpawnPost, OnPlayerSpawnPost);
}

public void OnPlayerSpawnPost(int client)
{
    if(!g_cvEnable.BoolValue)
        return;

    if(!IsPlayerAlive(client))
        return;

    SetEntProp(client, Prop_Data, "m_iFrags", g_iScoreBoard[client].iFrags);

    SetEntProp(client, Prop_Data, "m_iDeaths", g_iScoreBoard[client].iDeaths);

    CS_SetMVPCount(client, g_iScoreBoard[client].iMVPs);

    CS_SetClientContributionScore(client, g_iScoreBoard[client].iScore);

    CS_SetClientAssists(client, g_iScoreBoard[client].iAssists);
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

public Action CMD_SwapRs(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CPrintToChat(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(!IsClientInGame(client))
        return Plugin_Handled;
    
    if((args != 1) && (args != 2))
    {
        ReplyToCommand(client, "%t", "CMD_Swap_Usage");
        return Plugin_Handled;
    }
    
    char target_name[MAX_TARGET_LENGTH];
    char buffer[64];
    int target_list[MAXPLAYERS];
    bool tn_is_ml;
    int target_count;
    
    GetCmdArg(1, buffer, sizeof(buffer));
    if(StrEqual(buffer, "@spec", false) || StrEqual(buffer, "@spectator", false))
    {
        ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
        return Plugin_Handled;
    }
    
    if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }
    
    GetCmdArg(2, buffer, sizeof(buffer));
    int value = StringToInt(buffer);
    int team;
    
    for(int i = 0; i < target_count; i++)
    {
        if(IsClientInGame(target_list[i]))
        {
            team = GetClientTeam(target_list[i]);
            if(team >= 2)
            {
                if(!value)
                {
                    if(team == CS_TEAM_T)
                    {
                        CS_SwitchTeam(target_list[i], CS_TEAM_CT);
                    }
                    else
                    {
                        CS_SwitchTeam(target_list[i], CS_TEAM_T);
                    }
                    
                    if(IsPlayerAlive(target_list[i]))
                    {
                        CS_RespawnPlayer(target_list[i]);
                    }
                }
                else
                {
                    if(team == CS_TEAM_T)
                    {
                        SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_CT);
                    }
                    else
                    {
                        SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_T);
                    }
                }

                g_iScoreBoard[target_list[i]].iFrags = 0;
                SetEntProp(target_list[i], Prop_Data, "m_iFrags", g_iScoreBoard[target_list[i]].iFrags);

                g_iScoreBoard[target_list[i]].iDeaths = 0;
                SetEntProp(target_list[i], Prop_Data, "m_iDeaths", g_iScoreBoard[target_list[i]].iDeaths);

                g_iScoreBoard[target_list[i]].iMVPs = 0;
                CS_SetMVPCount(target_list[i], g_iScoreBoard[target_list[i]].iMVPs);

                g_iScoreBoard[target_list[i]].iScore = 0;
                CS_SetClientContributionScore(target_list[i], g_iScoreBoard[target_list[i]].iScore);

                g_iScoreBoard[target_list[i]].iAssists = 0;
                CS_SetClientAssists(target_list[i], g_iScoreBoard[target_list[i]].iAssists);
            }
            else if(!tn_is_ml)
            {
                ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
                return Plugin_Handled;
            }
        }
    }
    
    if(tn_is_ml)
    {
        ShowActivity2(client, ">", "%t", "CMD_Swap", target_name);
        LogActionEx(client, "%t", "CMD_Swap", target_name);
    }
    else
    {
        ShowActivity2(client, ">", "%t", "CMD_Swap", "_s", target_name);
        LogActionEx(client, "%t", "CMD_Swap", "_s", target_name);
    }
    return Plugin_Handled;
}

public Action Command_RoundDisqualified(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CPrintToChat(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(!IsValidClient(client))
        return Plugin_Handled;

    if(g_iClientInChargeRoundDisqualified > -1 && IsValidClient(g_iClientInChargeRoundDisqualified))
    {
        CPrintToChat(client, "%t", "Round Already Disqualified", g_iClientInChargeRoundDisqualified);
        return Plugin_Handled;
    }

    g_iClientInChargeRoundDisqualified = client;

    int roundNumber = GameRules_GetProp("m_totalRoundsPlayed") + 1;

    SetHudTextParams(g_fHudPosX, g_fHudPosY, g_fHudUpdate, g_iHudRgba[0], g_iHudRgba[1], g_iHudRgba[2], g_iHudRgba[3], 0, 0.0, 0.0, 0.0);

    if(args == 0)
    {
        CPrintToChatAll("%t", "Chat Round Disqualified No Reason");
        DisplayCenterTextToAll("%t", "Global Round Disqualified No Reason");
        ShowSyncHudText(client, g_hHUD, "%t", "Global Round Disqualified No Reason");

        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGame(i) && IsPlayerAlive(i))
            {
                SetEntityMoveType(i, MOVETYPE_NONE);
                SetEntProp(i, Prop_Data, "m_takedamage", GOD_ON, 1);
            }
        }

        CS_TerminateRound(g_cvRoundDisqualifiedEndTime.FloatValue, CSRoundEnd_Draw, true);

        if(g_cvLogEnable.BoolValue)
        {
            LogToFileEx(g_sFilePath, "\"%N\" desqualificou a ronda %i sem razão", client, roundNumber);
        }
    }
    else
    {
        char Arguments[256];
        GetCmdArgString(Arguments, sizeof(Arguments));

        CPrintToChatAll("%t", "Chat Round Disqualified With Reason", Arguments);
        DisplayCenterTextToAll("%t", "Global Round Disqualified With Reason", Arguments);
        ShowSyncHudText(client, g_hHUD, "%t", "Global Round Disqualified With Reason", Arguments);

        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGame(i) && IsPlayerAlive(i))
            {
                SetEntityMoveType(i, MOVETYPE_NONE);
                SetEntProp(i, Prop_Data, "m_takedamage", GOD_ON, 1);
            }
        }

        CS_TerminateRound(g_cvRoundDisqualifiedEndTime.FloatValue, CSRoundEnd_Draw, true);

        if(g_cvLogEnable.BoolValue)
        {
            LogToFileEx(g_sFilePath, "\"%N\" desqualificou a ronda %i com a razão: %s", client, roundNumber, Arguments);
        }
    }

    return Plugin_Handled;
}

void DisplayCenterTextToAll(const char[] message, any ...)
{
    char buffer[MAX_MESSAGE_LENGTH];
    VFormat(buffer, sizeof(buffer), message, 2);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
        {
            continue;
        }

        PrintCenterText(i, "%s", buffer);
    }
}

stock void LogActionEx(int client, char[] message, any ...)
{
    char buffer[256];
    SetGlobalTransTarget(LANG_SERVER);
    VFormat(buffer, sizeof(buffer), message, 3);
    LogMessage("%N: %s", client, buffer);
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