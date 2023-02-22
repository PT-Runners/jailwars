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

#define SPECMODE_NONE 				0
#define SPECMODE_FIRSTPERSON 		4
#define SPECMODE_3RDPERSON 			5
#define SPECMODE_FREELOOK	 		6

#define SPECLIST_FLAG "d"
#define STAFF_SPECLIST_UPDATE_INTERVAL 0.2
#define COUNT_CT_SPECLIST_UPDATE_INTERVAL 0.9

#define COUNT_CT_SPECLIST_SYSTEM_UPDATE_INTERVAL 1.0

#define TOP_X_KILLS 10

#define CONFIG_DIR "sourcemod/jailwars/"

enum struct ScoreboardStats
{
    int iFrags;
    int iDeaths;
    int iMVPs;
    int iScore;
    int iAssists;
}

enum struct SpecPlayer
{
    int client;
    int count;
}

enum struct FragPlayer
{
    int client;
    int frags;
}

ScoreboardStats g_iScoreBoard[MAXPLAYERS + 1][2];

ConVar g_cvEnable;
ConVar g_cvPrisonersArmor;
ConVar g_cvRandomPrisonerWeapon;
ConVar g_cvLogEnable;
ConVar g_cvRoundDisqualifiedEndTime;
ConVar g_cvPauseTime;
ConVar g_cvRestartGame;

Handle g_hHUD;
Handle g_hRoundTimer;
Handle g_hCountCTSpecTimer;
Handle g_hStaffSpeclistHudHintTimers[MAXPLAYERS+1];
Handle g_hCountCTSpeclistHudHintTimers[MAXPLAYERS+1];

ArrayList g_aCountCTSpecList;

float g_fHudPosX = -1.0;
float g_fHudPosY = 0.2;
float g_fHudUpdate = 5.0;

float g_fHudStaffSpeclistPosX = 0.2;
float g_fHudStaffSpeclistPosY = 0.2;
float g_fHudStaffSpeclistUpdate = 2.0;

float g_fHudCountCTSpeclistPosX = -1.0;
float g_fHudCountCTSpeclistPosY = 0.2;
float g_fHudCountCTSpeclistUpdate = 2.0;

char g_sRandomPrisonerWeapon[64];
char g_sFilePath[PLATFORM_MAX_PATH];

int g_iHudRgba[4] = { 139, 0, 0 , 255};

int g_iHudStaffSpecListRgba[4] = { 255, 255, 0 , 255};

int g_iHudCountCTSpecListRgba[4] = { 140, 0, 0 , 255};

int g_iClientInChargeRoundDisqualified = -1;
int g_iRoundTime = -1;

bool g_bIsWarmup = false;
bool g_bIsFreeday = false;

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

    g_aCountCTSpecList = new ArrayList();

    RegAdminCmd("sm_disqualify", Command_RoundDisqualified, ADMFLAG_BAN);
    RegAdminCmd("sm_desqualificar", Command_RoundDisqualified, ADMFLAG_BAN);

    RegAdminCmd("sm_disqualifyplayer", Command_RoundDisqualifiedPlayer, ADMFLAG_BAN);
    RegAdminCmd("sm_desqualificarjogador", Command_RoundDisqualifiedPlayer, ADMFLAG_BAN);

    RegAdminCmd("sm_pause", Command_Pause, ADMFLAG_BAN);

    RegAdminCmd("sm_swaprs", CMD_SwapRs, ADMFLAG_BAN, "Swap the targets team");

    RegAdminCmd("sm_staffspeclist", Command_StaffSpecList, ADMFLAG_BAN);
    RegAdminCmd("sm_countctspec", Command_CountCTSpec, ADMFLAG_BAN);
    RegAdminCmd("sm_countctspeclist", Command_CountCTSpecList, ADMFLAG_BAN);

    RegAdminCmd("sm_topkills_jw_t", Command_TopKillsTerrorist, ADMFLAG_BAN);
    RegAdminCmd("sm_topkills_jw_ct", Command_TopKillsCounterTerrorist, ADMFLAG_BAN);

    LoadTranslations("common.phrases.txt");
    LoadTranslations("jailwars.phrases");

    HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundPreEnd, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    g_cvRestartGame = FindConVar("mp_restartgame");
    g_cvRestartGame.AddChangeHook(OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvRandomPrisonerWeapon)
        g_cvRandomPrisonerWeapon.GetString(g_sRandomPrisonerWeapon, sizeof(g_sRandomPrisonerWeapon));
    else if(convar == g_cvEnable)
    {
        if(g_cvEnable.BoolValue)
        {
            ExecuteStartConfigJailwars();

            if (g_hCountCTSpecTimer != null)
            {
                KillTimer(g_hCountCTSpecTimer);
                g_hCountCTSpecTimer = null;
            }

            g_hCountCTSpecTimer = CreateTimer(COUNT_CT_SPECLIST_SYSTEM_UPDATE_INTERVAL, Timer_CountCTSpecTimer, _, TIMER_REPEAT);

            g_bIsWarmup = GameRules_GetProp("m_bWarmupPeriod") == 1;

            g_bIsFreeday = IsFreeday();

            // Enable timers on all players in game.
            for(int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i))
                    continue;

                if(!CheckAdminFlag(i, SPECLIST_FLAG))
                    continue;

                CreateHudHintTimer(i);
            }
        }
        else
        {
            if (g_hCountCTSpecTimer != null)
            {
                KillTimer(g_hCountCTSpecTimer);
                g_hCountCTSpecTimer = null;
            }

            // Kill all of the active timers.
            for(int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i))
                    continue;

                if(!CheckAdminFlag(i, SPECLIST_FLAG))
                    continue;

                KillHudHintTimer(i);
                KillCountCTSpecHudHintTimer(i);

            }
        }
    }
    else if(convar == g_cvRestartGame)
    {
        if(g_cvEnable.BoolValue)
            ResetScoreboardStats();
    }
}

public void OnConfigsExecuted()
{
    if(g_cvEnable.BoolValue)
    {
        ExecuteStartConfigJailwars();

        g_hCountCTSpecTimer = CreateTimer(COUNT_CT_SPECLIST_SYSTEM_UPDATE_INTERVAL, Timer_CountCTSpecTimer, _, TIMER_REPEAT);
    }

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
}

public void Event_RoundPreEnd(Handle event, const char[] name, bool dontBroadcast)
{
    if(!g_cvEnable.BoolValue)
        return;

    if(g_bIsWarmup)
    {
        ResetScoreboardStats();
        g_bIsWarmup = false;
        return;
    }

    if(g_bIsFreeday)
    {
        ResetScoreboardStats();
        g_bIsFreeday = false;
        return;
    }

    for(int i = 1; i <= MaxClients; i++)
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

    g_bIsWarmup = GameRules_GetProp("m_bWarmupPeriod") == 1;

    g_bIsFreeday = IsFreeday();

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

        CReplyToCommand(client, "{green}> {default}Recebeste uma %s.", szWeaponName);
        break;
    }
}

public void OnClientPostAdminCheck(int client)
{
    if(!g_cvEnable.BoolValue)
        return;

    SDKHook(client, SDKHook_SpawnPost, OnPlayerSpawnPost);

    if(!CheckAdminFlag(client, SPECLIST_FLAG))
        return;

    CreateHudHintTimer(client);
    CreateCountCTSpecHudHintTimer(client);
}

public void OnClientDisconnect(int client)
{
    if(!CheckAdminFlag(client, SPECLIST_FLAG))
        return;

    KillHudHintTimer(client);
    KillCountCTSpecHudHintTimer(client);
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

public Action Command_StaffSpecList(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if (g_hStaffSpeclistHudHintTimers[client] != INVALID_HANDLE)
    {
        KillHudHintTimer(client);
        CReplyToCommand(client, "%t", "Staff Spec List Disabled");
    }
    else
    {
        CreateHudHintTimer(client);
        CReplyToCommand(client, "%t", "Staff Spec List Enabled");
    }

    return Plugin_Handled;
}

public Action Command_CountCTSpec(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    ArrayList spec = GetCTSpecCountArrayList();

    if(spec.Length == 0)
    {
        CReplyToCommand(client, "%t", "Count CT Spec No Players Found");
    }
    else
    {
        CReplyToCommand(client, "{orange}-----{default}");
    }

    for(int i = 0; i < spec.Length; i++)
    {
        SpecPlayer p;
        spec.GetArray(i, p);
        CReplyToCommand(client, "%t", "Count CT Spec Player", p.client, p.count);
    }

    if(spec.Length > 0)
    {
        CReplyToCommand(client, "{orange}-----{default}");
    }

    delete spec;

    return Plugin_Handled;
}

public Action Command_CountCTSpecList(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if (g_hCountCTSpeclistHudHintTimers[client] != INVALID_HANDLE)
    {
        KillCountCTSpecHudHintTimer(client);
        CReplyToCommand(client, "%t", "Count CT Spec List Disabled");
    }
    else
    {
        CreateCountCTSpecHudHintTimer(client);
        CReplyToCommand(client, "%t", "Count CT Spec List Enabled");
    }

    return Plugin_Handled;
}

public Action Command_TopKillsTerrorist(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    ArrayList a_TopKillsTerror = new ArrayList(sizeof(FragPlayer));
    FragPlayer fragPlayer;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;

        int indexTeam = GetIndexTeamScoreboard(CS_TEAM_T);

        if(indexTeam == -1)
            continue;

        fragPlayer.client = i;
        fragPlayer.frags = g_iScoreBoard[i][indexTeam].iFrags;

        a_TopKillsTerror.PushArray(fragPlayer, sizeof(FragPlayer));
    }

    a_TopKillsTerror.SortCustom(TopKillsDescSort);

    for(int i = 0; i < TOP_X_KILLS; i++)
    {
        if(i >= a_TopKillsTerror.Length)
            break;

        a_TopKillsTerror.GetArray(i, fragPlayer, sizeof(FragPlayer));
        
        PrintToConsole(client, "%iº - Player: %N | Frags: %i", (i+1), fragPlayer.client, fragPlayer.frags);
    }

    delete a_TopKillsTerror;

    return Plugin_Handled;
}

public Action Command_TopKillsCounterTerrorist(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    ArrayList a_TopKillsTerror = new ArrayList(sizeof(FragPlayer));
    FragPlayer fragPlayer;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;

        int indexTeam = GetIndexTeamScoreboard(CS_TEAM_CT);

        if(indexTeam == -1)
            continue;

        fragPlayer.client = i;
        fragPlayer.frags = g_iScoreBoard[i][indexTeam].iFrags;

        a_TopKillsTerror.PushArray(fragPlayer, sizeof(FragPlayer));
    }

    a_TopKillsTerror.SortCustom(TopKillsDescSort);

    for(int i = 0; i < TOP_X_KILLS; i++)
    {
        if(i >= a_TopKillsTerror.Length)
            break;

        a_TopKillsTerror.GetArray(i, fragPlayer, sizeof(FragPlayer));
        
        PrintToConsole(client, "%iº - Player: %N | Frags: %i", (i+1), fragPlayer.client, fragPlayer.frags);
    }

    delete a_TopKillsTerror;

    return Plugin_Handled;
}

public int TopKillsDescSort(int index1, int index2, Handle array, Handle hndl)
{
    FragPlayer a, b;
    
    GetArrayArray(array, index1, a);
    GetArrayArray(array, index2, b);

    return a.frags > b.frags ? -1 : 1;
}

public int SpecDescSort(int index1, int index2, Handle array, Handle hndl)
{
    SpecPlayer a, b;
    GetArrayArray(array, index1, a);
    GetArrayArray(array, index2, b);

    if(a.count == a.client)
        return 0;

    return a.count > b.count ? -1 : 1;
}

public int SpecAscSort(int index1, int index2, Handle array, Handle hndl)
{
    SpecPlayer a, b;
    GetArrayArray(array, index1, a);
    GetArrayArray(array, index2, b);

    if(a.count == a.client)
        return 0;

    return a.count > b.count ? 1 : -1;
}

public Action Command_Pause(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
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
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(!IsClientInGame(client))
        return Plugin_Handled;

    if((args != 1) && (args != 2))
    {
        CReplyToCommand(client, "%t", "CMD_Swap_Usage");
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
        CReplyToCommand(client, "%t", "CMD_OnlyInTeam");
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
                SwapTeam(target_list[i], !!value);
            }
            else if(!tn_is_ml)
            {
                CReplyToCommand(client, "%t", "CMD_OnlyInTeam");
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
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(!IsValidClient(client))
        return Plugin_Handled;

    if(g_iClientInChargeRoundDisqualified > -1 && IsValidClient(g_iClientInChargeRoundDisqualified))
    {
        CReplyToCommand(client, "%t", "Round Already Disqualified", g_iClientInChargeRoundDisqualified);
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

public Action Command_RoundDisqualifiedPlayer(int client, int args)
{
    if(!g_cvEnable.BoolValue)
    {
        CReplyToCommand(client, "%t", "Jailwars Disabled");
        return Plugin_Handled;
    }

    if(!IsValidClient(client))
        return Plugin_Handled;

    char buffer[64];

    if(!GetCmdArg(1, buffer, sizeof(buffer)))
    {
        CReplyToCommand(client, "%t", "CMD_DisqualifyPlayer_Usage");
        return Plugin_Handled;
    }

    char target_name[MAX_TARGET_LENGTH];

    int target_list[MAXPLAYERS];
    bool tn_is_ml;
    int target_count;

    target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml);

    if (target_count < 1)
	{
		ReplyToTargetError(client, target_count);
	}

    int iTarget = target_list[0];

    if(GetClientTeam(iTarget) != CS_TEAM_T && GetClientTeam(iTarget) !=  CS_TEAM_CT)
    {
        CReplyToCommand(client, "%t", "CMD_OnlyInTeam");
        return Plugin_Handled;
    }

    char sReasonStr[128];
    char sArgPart[128];
    for (int iArg = 2; iArg <= args; iArg++)
    {
        GetCmdArg(iArg, sArgPart, sizeof(sArgPart));
        Format(sReasonStr, sizeof(sReasonStr), "%s %s", sReasonStr, sArgPart);
    }
    // Remove the space at the beginning
    TrimString(sReasonStr);

    if(g_iClientInChargeRoundDisqualified > -1 && IsValidClient(g_iClientInChargeRoundDisqualified))
    {
        CReplyToCommand(client, "%t", "Round Already Disqualified", g_iClientInChargeRoundDisqualified);
        return Plugin_Handled;
    }

    if(GetClientTeam(iTarget) == CS_TEAM_CT)
    {
        bool bNextRound = false;

        SwapTeam(iTarget, bNextRound);
    }

    g_iClientInChargeRoundDisqualified = client;

    int roundNumber = GameRules_GetProp("m_totalRoundsPlayed") + 1;

    SetHudTextParams(g_fHudPosX, g_fHudPosY, g_fHudUpdate, g_iHudRgba[0], g_iHudRgba[1], g_iHudRgba[2], g_iHudRgba[3], 0, 0.0, 0.0, 0.0);

    if(StrEqual(sReasonStr, ""))
    {
        CPrintToChatAll("%t", "Chat Round Disqualified Player No Reason", iTarget);
        DisplayCenterTextToAll("%t", "Global Round Disqualified Player No Reason", iTarget);
        ShowSyncHudText(client, g_hHUD, "%t", "Global Round Disqualified Player No Reason", iTarget);

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
            LogToFileEx(g_sFilePath, "\"%N\" desqualificou a ronda %i devido jogador %N sem razão", client, roundNumber, iTarget);
        }
    }
    else
    {
        CPrintToChatAll("%t", "Chat Round Disqualified Player With Reason", iTarget, sReasonStr);
        DisplayCenterTextToAll("%t", "Global Round Disqualified Player With Reason", iTarget, sReasonStr);
        ShowSyncHudText(client, g_hHUD, "%t", "Global Round Disqualified Player With Reason", iTarget, sReasonStr);

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
            LogToFileEx(g_sFilePath, "\"%N\" desqualificou a ronda %i devidor jogador %N com a razão: %s", client, roundNumber, iTarget, sReasonStr);
        }
    }

    return Plugin_Handled;
}

void SwapTeam(int client, bool bNextRound)
{
    int team = GetClientTeam(client);

    int indexTeam = GetIndexTeamScoreboard(team);

    int oppositeIndexTeam = GetOppositeIndexTeamScoreboard(team);

    g_iScoreBoard[client][indexTeam].iFrags = GetEntProp(client, Prop_Data, "m_iFrags");
    SetEntProp(client, Prop_Data, "m_iFrags", g_iScoreBoard[client][oppositeIndexTeam].iFrags);

    g_iScoreBoard[client][indexTeam].iDeaths = GetEntProp(client, Prop_Data, "m_iDeaths");
    SetEntProp(client, Prop_Data, "m_iDeaths", g_iScoreBoard[client][oppositeIndexTeam].iDeaths);

    g_iScoreBoard[client][indexTeam].iMVPs = CS_GetMVPCount(client);
    CS_SetMVPCount(client, g_iScoreBoard[client][oppositeIndexTeam].iMVPs);

    g_iScoreBoard[client][indexTeam].iScore = CS_GetClientContributionScore(client);
    CS_SetClientContributionScore(client, g_iScoreBoard[client][oppositeIndexTeam].iScore);

    g_iScoreBoard[client][indexTeam].iAssists = CS_GetClientAssists(client);
    CS_SetClientAssists(client, g_iScoreBoard[client][oppositeIndexTeam].iAssists);

    if(!bNextRound)
    {
        if(team == CS_TEAM_T)
        {
            CS_SwitchTeam(client, CS_TEAM_CT);
        }
        else
        {
            CS_SwitchTeam(client, CS_TEAM_T);
        }

        if(IsPlayerAlive(client))
        {
            CS_RespawnPlayer(client);
        }

        return;
    }

    if(team == CS_TEAM_T)
    {
        SetEntProp(client, Prop_Data, "m_iPendingTeamNum", CS_TEAM_CT);
    }
    else
    {
        SetEntProp(client, Prop_Data, "m_iPendingTeamNum", CS_TEAM_T);
    }
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
    CReplyToCommand(client, "{green}> {default}Recebeste %i armadura.", g_cvPrisonersArmor.IntValue);
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

public Action Timer_CountCTSpecTimer(Handle timer)
{
    if(g_hCountCTSpecTimer == null)
        return Plugin_Stop;

    g_aCountCTSpecList = GetCTSpecListCountArrayList();

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

    for(int i = 1; i <= MaxClients; i++) {

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

    for(int i = 1; i <= MaxClients; i++) {

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

stock bool CheckAdminFlag(int client, const char[] flags)
{
	if(StrEqual(flags, "")) {
		return true;
	}

	int iCount = 0;
	char sflagNeed[22][8], sflagFormat[64];
	bool bEntitled = false;

	Format(sflagFormat, sizeof(sflagFormat), flags);
	ReplaceString(sflagFormat, sizeof(sflagFormat), " ", "");
	iCount = ExplodeString(sflagFormat, ",", sflagNeed, sizeof(sflagNeed), sizeof(sflagNeed[]));

	for (int i = 0; i < iCount; i++)
	{
		if ((GetUserFlagBits(client) & ReadFlagString(sflagNeed[i]) == ReadFlagString(sflagNeed[i])) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
		{
			bEntitled = true;
			break;
		}
	}

	return bEntitled;
}

public Action Timer_UpdateHudHint(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsClientObserver(client) || IsFakeClient(client))
        return Plugin_Continue;

    int iSpecModeUser = GetEntProp(client, Prop_Send, "m_iObserverMode");
    int iTargetUser, iSpecMode, iTarget;
    bool bDisplayHint = false;

    char szText[2048];
    szText[0] = '\0';

    if (iSpecModeUser == SPECMODE_FIRSTPERSON || iSpecModeUser == SPECMODE_3RDPERSON)
    {
        // Find out who the User is spectating.
        iTargetUser = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

        if (iTargetUser < 1)
            return Plugin_Continue;

        Format(szText, sizeof(szText), "%t", "Spectating", iTargetUser);

        for(int i = 1; i <= MaxClients; i++)
        {
            if (client == i || !IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i))
                continue;

            iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

            // The client isn't spectating any one person, so ignore them.
            if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
                continue;

            if(!CheckAdminFlag(i, SPECLIST_FLAG))
                continue;

            // Find out who the client is spectating.
            iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

            if(iTarget == -1)
                continue;

            // Are they spectating our player?
            if (iTarget == iTargetUser)
            {
                Format(szText, sizeof(szText), "%s%N\n", szText, i);
                bDisplayHint = true;
            }
        }
    }

    if (bDisplayHint)
    {
        SetHudTextParams(g_fHudStaffSpeclistPosX, g_fHudStaffSpeclistPosY, g_fHudStaffSpeclistUpdate, g_iHudStaffSpecListRgba[0], g_iHudStaffSpecListRgba[1], g_iHudStaffSpecListRgba[2], g_iHudStaffSpecListRgba[3], 0, 0.0, 0.1, 0.1);
        ShowHudText(client, -1, szText);
        bDisplayHint = false;
    }

    return Plugin_Continue;
}

public Action Timer_UpdateCountCTSpecHudHint(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsClientObserver(client) || IsFakeClient(client))
        return Plugin_Continue;

    bool bDisplayHint = false;

    char szText[2048];
    szText[0] = '\0';

    if(g_aCountCTSpecList == null)
        return Plugin_Continue;

    if(g_aCountCTSpecList.Length == 0)
        return Plugin_Continue;

    bDisplayHint = true;
    Format(szText, sizeof(szText), "%t", "Count Spectators");

    for(int i = 0; i < g_aCountCTSpecList.Length; i++)
    {
        SpecPlayer p;
        g_aCountCTSpecList.GetArray(i, p);
        Format(szText, sizeof(szText), "%s%N : %i\n", szText, p.client, p.count);
    }

    if (bDisplayHint)
    {
        SetHudTextParams(g_fHudCountCTSpeclistPosX, g_fHudCountCTSpeclistPosY, g_fHudCountCTSpeclistUpdate, g_iHudCountCTSpecListRgba[0], g_iHudCountCTSpecListRgba[1], g_iHudCountCTSpecListRgba[2], g_iHudCountCTSpecListRgba[3], 0, 0.0, 0.1, 0.1);
        ShowHudText(client, -1, szText);
        bDisplayHint = false;
    }

    return Plugin_Continue;
}

void CreateHudHintTimer(int client)
{
    g_hStaffSpeclistHudHintTimers[client] = CreateTimer(STAFF_SPECLIST_UPDATE_INTERVAL, Timer_UpdateHudHint, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void KillHudHintTimer(int client)
{
    if (g_hStaffSpeclistHudHintTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hStaffSpeclistHudHintTimers[client]);
        g_hStaffSpeclistHudHintTimers[client] = INVALID_HANDLE;
    }
}

void CreateCountCTSpecHudHintTimer(int client)
{
    g_hCountCTSpeclistHudHintTimers[client] = CreateTimer(COUNT_CT_SPECLIST_UPDATE_INTERVAL, Timer_UpdateCountCTSpecHudHint, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void KillCountCTSpecHudHintTimer(int client)
{
    if (g_hCountCTSpeclistHudHintTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hCountCTSpeclistHudHintTimers[client]);
        g_hCountCTSpeclistHudHintTimers[client] = INVALID_HANDLE;
    }
}

void ResetScoreboardStats()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;

        for(int team = 0; team <= 1; team++)
        {
            g_iScoreBoard[i][team].iFrags = 0;
            g_iScoreBoard[i][team].iDeaths = 0;
            g_iScoreBoard[i][team].iMVPs = 0;
            g_iScoreBoard[i][team].iScore = 0;
            g_iScoreBoard[i][team].iAssists = 0;
        }
    }
}

bool IsFreeday()
{
    if(!MyJailbreak_IsEventDayRunning())
        return false;

    char EventDay[64];
    MyJailbreak_GetEventDayName(EventDay);

    if(!StrEqual(EventDay, "freeday", false))
        return false;

    return true;
}

void ExecuteStartConfigJailwars()
{
    ServerCommand("exec %s%s", CONFIG_DIR, "start.cfg");
}

ArrayList GetCTSpecCountArrayList()
{
    int iTarget, iSpecMode;

    ArrayList spec = new ArrayList(sizeof(SpecPlayer));

    int index;

    for(int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if(IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
        {
            index = spec.FindValue(i, SpecPlayer::client);

            if(index == -1)
            {
                SpecPlayer p;
                p.client = i;
                p.count = 0;
                spec.PushArray(p);
                continue;
            }
        }

        if(!IsClientObserver(i) || IsFakeClient(i))
            continue;

        if(!CheckAdminFlag(i, SPECLIST_FLAG))
            continue;

        iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

        // The client isn't spectating any one person, so ignore them.
        if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
            continue;

        // Find out who the client is spectating.
        iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

        if(iTarget == -1)
            continue;

        if (!IsClientInGame(iTarget))
            continue;

        if(GetClientTeam(iTarget) != CS_TEAM_CT)
            continue;

        index = spec.FindValue(iTarget, SpecPlayer::client);

        if(index == -1)
        {
            SpecPlayer p;
            p.client = iTarget;
            p.count = 1;
            spec.PushArray(p);
            continue;
        }

        SpecPlayer p;
        spec.GetArray(index, p);
        p.count++;

        spec.SetArray(index, p);
    }

    spec.SortCustom(SpecDescSort);

    return spec;
}

ArrayList GetCTSpecListCountArrayList()
{
    int iTarget, iSpecMode;

    ArrayList spec = new ArrayList(sizeof(SpecPlayer));

    int index;

    for(int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if(IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
        {
            index = spec.FindValue(i, SpecPlayer::client);

            if(index == -1)
            {
                SpecPlayer p;
                p.client = i;
                p.count = 0;
                spec.PushArray(p);
                continue;
            }
        }

        if(!IsClientObserver(i) || IsFakeClient(i))
            continue;

        if(!CheckAdminFlag(i, SPECLIST_FLAG))
            continue;

        iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

        // The client isn't spectating any one person, so ignore them.
        if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
            continue;

        // Find out who the client is spectating.
        iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

        if(iTarget == -1)
            continue;

        if (!IsClientInGame(iTarget))
            continue;

        if(GetClientTeam(iTarget) != CS_TEAM_CT)
            continue;

        index = spec.FindValue(iTarget, SpecPlayer::client);

        if(index == -1)
        {
            SpecPlayer p;
            p.client = iTarget;
            p.count = 1;
            spec.PushArray(p);
            continue;
        }

        SpecPlayer p;
        spec.GetArray(index, p);
        p.count++;

        spec.SetArray(index, p);
    }

    ArrayList filterSpec = spec.Clone();

    for(int i = 0; i < spec.Length; i++)
    {
        SpecPlayer p;
        spec.GetArray(i, p);

        if(p.count == 1)
        {
            filterSpec.Erase(i);
        }
    }

    filterSpec.SortCustom(SpecAscSort);

    delete spec;

    return filterSpec;
}