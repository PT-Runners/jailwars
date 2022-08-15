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

ScoreboardStats g_iScoreBoard[MAXPLAYERS + 1][2];

ConVar g_cvEnable;
ConVar g_cvPrisonersArmor;
ConVar g_cvRandomPrisonerWeapon;
ConVar g_cvLogEnable;
ConVar g_cvRoundDisqualifiedEndTime;
ConVar g_cvPauseTime;

Handle g_hHUD;
Handle g_hRoundTimer;

float g_fHudPosX = -1.0;
float g_fHudPosY = 0.2;
float g_fHudUpdate = 5.0; 

char g_sRandomPrisonerWeapon[64];
char g_sFilePath[PLATFORM_MAX_PATH];

int g_iHudRgba[4] = { 139, 0, 0 , 255};
int g_iClientInChargeRoundDisqualified = -1;
int g_iRoundTime = -1;

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
    g_cvPauseTime = CreateConVar("sm_jailwars_pause_time", "120.0", "Pause time for !pause", _, true, 0.0, true, 320.0);

    AutoExecConfig();

    g_hHUD = CreateHudSynchronizer();

    RegAdminCmd("sm_disqualify", Command_RoundDisqualified, ADMFLAG_BAN);
    RegAdminCmd("sm_desqualificar", Command_RoundDisqualified, ADMFLAG_BAN);
    RegAdminCmd("sm_pause", Command_Pause, ADMFLAG_BAN);

    RegAdminCmd("sm_swaprs", CMD_SwapRs, ADMFLAG_BAN, "Swap the targets team");

    LoadTranslations("jailwars.phrases");

    HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
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
    delete g_hRoundTimer;
    g_iRoundTime = -1;

    for(int i = 1; i < MAXPLAYERS; i++)
    {
        if(!IsClientInGame(i))
            continue;

        int indexTeam = GetIndexTeamScoreboard(GetClientTeam(i));

        if(indexTeam == -1)
            continue;
        
        g_iScoreBoard[i][indexTeam].iFrags = GetEntProp(i, Prop_Data, "m_iFrags");
        g_iScoreBoard[i][indexTeam].iDeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
        g_iScoreBoard[i][indexTeam].iMVPs = CS_GetMVPCount(i);
        g_iScoreBoard[i][indexTeam].iScore = CS_GetClientContributionScore(i);
        g_iScoreBoard[i][indexTeam].iAssists = CS_GetClientAssists(i);
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

    SetArmorPrisioner(client);

    int indexTeam = GetIndexTeamScoreboard(GetClientTeam(client));

    if(indexTeam == -1)
        return;

    SetEntProp(client, Prop_Data, "m_iFrags", g_iScoreBoard[client][indexTeam].iFrags);

    SetEntProp(client, Prop_Data, "m_iDeaths", g_iScoreBoard[client][indexTeam].iDeaths);

    CS_SetMVPCount(client, g_iScoreBoard[client][indexTeam].iMVPs);

    CS_SetClientContributionScore(client, g_iScoreBoard[client][indexTeam].iScore);

    CS_SetClientAssists(client, g_iScoreBoard[client][indexTeam].iAssists);
}

public Action Command_Pause(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CPrintToChat(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(IsPaused())
    {
        Unpause();

        CPrintToChatAll("{green}--------------{default}");
        CPrintToChatAll("%t", "Unpaused");
        CPrintToChatAll("{green}--------------{default}");
        return Plugin_Handled;
    }

    float pauseTime = g_cvPauseTime.FloatValue;

    char buffer[6];
    GetCmdArg(1, buffer, sizeof(buffer));

    if(!StrEqual(buffer, ""))
    {
        pauseTime = StringToFloat(buffer);
    }

    if(pauseTime == 0.0)
    {
        pauseTime = 600.0;
    }
    
    Pause(pauseTime);

    CPrintToChatAll("{darkred}--------------{default}");
    CPrintToChatAll("%t", "Paused");
    CPrintToChatAll("{darkred}--------------{default}");

    return Plugin_Handled;
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
                int indexTeam = GetIndexTeamScoreboard(team);
                
                int oppositeIndexTeam = GetOppositeIndexTeamScoreboard(team);

                g_iScoreBoard[target_list[i]][indexTeam].iFrags = GetEntProp(target_list[i], Prop_Data, "m_iFrags");
                SetEntProp(target_list[i], Prop_Data, "m_iFrags", g_iScoreBoard[target_list[i]][oppositeIndexTeam].iFrags);

                g_iScoreBoard[target_list[i]][indexTeam].iDeaths = GetEntProp(target_list[i], Prop_Data, "m_iDeaths");
                SetEntProp(target_list[i], Prop_Data, "m_iDeaths", g_iScoreBoard[target_list[i]][oppositeIndexTeam].iDeaths);

                g_iScoreBoard[target_list[i]][indexTeam].iMVPs = CS_GetMVPCount(target_list[i]);
                CS_SetMVPCount(target_list[i], g_iScoreBoard[target_list[i]][oppositeIndexTeam].iMVPs);

                g_iScoreBoard[target_list[i]][indexTeam].iScore = CS_GetClientContributionScore(target_list[i]);
                CS_SetClientContributionScore(target_list[i], g_iScoreBoard[target_list[i]][oppositeIndexTeam].iScore);

                g_iScoreBoard[target_list[i]][indexTeam].iAssists = CS_GetClientAssists(target_list[i]);
                CS_SetClientAssists(target_list[i], g_iScoreBoard[target_list[i]][oppositeIndexTeam].iAssists);

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

void SetArmorPrisioner(int client)
{
    if(!g_cvEnable.BoolValue)
        return;

    if(!g_cvPrisonersArmor.IntValue)
        return;

    if(MyJailbreak_IsEventDayRunning() || GameRules_GetProp("m_bWarmupPeriod") == 1)
        return;

    if(!IsValidClient(client, false, false))
        return;

    if(GetClientTeam(client) != CS_TEAM_T)
        return;

    SetEntProp(client, Prop_Data, "m_ArmorValue", g_cvPrisonersArmor.IntValue);
    CPrintToChat(client, "{green}> {default}Recebeste %i armadura.", g_cvPrisonersArmor.IntValue);
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

public Action Timer_RoundTimer(Handle timer)
{
    if(g_hRoundTimer == null)
        return Plugin_Stop;

    g_iRoundTime += 1;
    return Plugin_Continue;
}

public Action Timer_Unpause(Handle timer)
{
    if(!IsPaused())
        return Plugin_Stop;

    Unpause();
    return Plugin_Stop;
}

int GetOppositeIndexTeamScoreboard(int team)
{
    if(team == CS_TEAM_T)
        return 1;

    if(team == CS_TEAM_CT)
        return 0;

    return -1;
}

int GetIndexTeamScoreboard(int team)
{
    if(team == CS_TEAM_T)
        return 0;

    if(team == CS_TEAM_CT)
        return 1;

    return -1;
}

bool IsPaused()
{
    return g_hRoundTimer != null;
}

void Pause(float pauseTime)
{
    if (g_hRoundTimer != null)
    {
        KillTimer(g_hRoundTimer);
        g_hRoundTimer = null;
    }

    g_iRoundTime = GameRules_GetProp("m_iRoundTime", 4, 0);
    
    GameRules_SetProp("m_iRoundTime", -1);

    for(int i = 1; i < MaxClients; i++) {

        if(!IsValidClient(i, true, false))
            continue;

        SetEntityMoveType(i, MOVETYPE_NONE);
        DarkenScreen(i, true);
    }

    g_hRoundTimer = CreateTimer(1.0, Timer_RoundTimer, _, TIMER_REPEAT);
    CreateTimer(pauseTime, Timer_Unpause);
}

void Unpause()
{
    if (g_hRoundTimer != null)
    {
        KillTimer(g_hRoundTimer);
        g_hRoundTimer = null;
    }

    GameRules_SetProp("m_iRoundTime", g_iRoundTime, 4, 0);

    for(int i = 1; i < MaxClients; i++) {

        if(!IsValidClient(i, true, false))
            continue;

        SetEntityMoveType(i, MOVETYPE_WALK);
        DarkenScreen(i, false);
    }

    g_iRoundTime = -1;
}

stock void DarkenScreen(int client, bool dark)
{
	Handle hFadeClient = StartMessageOne("Fade", client);
	PbSetInt(hFadeClient, "duration", 1);
	PbSetInt(hFadeClient, "hold_time", 3);
	if(!dark)
	{
		PbSetInt(hFadeClient, "flags", 0x0010); // FFADE_STAYOUT	0x0008		ignores the duration, stays faded out until new ScreenFade message received
	}
	else
	{
		PbSetInt(hFadeClient, "flags", 0x0008); // FFADE_PURGE		0x0010		Purges all other fades, replacing them with this one
	}
	PbSetColor(hFadeClient, "clr", {0, 0, 0, 255});
	EndMessage();
}