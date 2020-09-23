#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <clientprefs>

#define PREFIX "{green}[{orange}HITMARKERS{green}] {default}%t"
#define HitmarkerOverlay1Vtf "overlays/belialg/hitmarkers/hitmarker0.vtf"
#define HitmarkerOverlay2Vtf "overlays/belialg/hitmarkers/hitmarker1.vtf"
#define HitmarkerOverlay3Vtf "overlays/belialg/hitmarkers/hitmarker2.vtf"
#define HitmarkerOverlay4Vtf "overlays/belialg/hitmarkers/hitmarker3.vtf"
#define HitmarkerOverlay5Vtf "overlays/belialg/hitmarkers/hitmarker4.vtf"
#define HitmarkerOverlay6Vtf "overlays/belialg/hitmarkers/hitmarker5.vtf"
#define HitmarkerOverlay7Vtf "overlays/belialg/hitmarkers/hitmarker6.vtf"
#define HitmarkerOverlay1VtfD "materials/overlays/belialg/hitmarkers/hitmarker0.vtf"
#define HitmarkerOverlay2VtfD "materials/overlays/belialg/hitmarkers/hitmarker1.vtf"
#define HitmarkerOverlay3VtfD "materials/overlays/belialg/hitmarkers/hitmarker2.vtf"
#define HitmarkerOverlay4VtfD "materials/overlays/belialg/hitmarkers/hitmarker3.vtf"
#define HitmarkerOverlay5VtfD "materials/overlays/belialg/hitmarkers/hitmarker4.vtf"
#define HitmarkerOverlay6VtfD "materials/overlays/belialg/hitmarkers/hitmarker5.vtf"
#define HitmarkerOverlay7VtfD "materials/overlays/belialg/hitmarkers/hitmarker6.vtf"
#define HitmarkerOverlay1Vmt "materials/overlays/belialg/hitmarkers/hitmarker0.vmt"
#define HitmarkerOverlay2Vmt "materials/overlays/belialg/hitmarkers/hitmarker1.vmt"
#define HitmarkerOverlay3Vmt "materials/overlays/belialg/hitmarkers/hitmarker2.vmt"
#define HitmarkerOverlay4Vmt "materials/overlays/belialg/hitmarkers/hitmarker3.vmt"
#define HitmarkerOverlay5Vmt "materials/overlays/belialg/hitmarkers/hitmarker4.vmt"
#define HitmarkerOverlay6Vmt "materials/overlays/belialg/hitmarkers/hitmarker5.vmt"
#define HitmarkerOverlay7Vmt "materials/overlays/belialg/hitmarkers/hitmarker6.vmt"
#define HitmarkerSoundEffect "belialg/hm.mp3"
#define HitmarkerSoundEffectD "sound/belialg/hm.mp3"
#define HitmarkerOverlay "overlays/belialg/hitmarkers/hitmarker"

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name			= "Hitmarkers",
	author			= "Nano",
	description		= "Show a hitmarker when you shoot enemies/bosses/objects (with sound effect)",
	version			= "1.1",
	url				= "https://steamcommunity.com/id/nano2k06/"
};

bool 	g_bEnemies	[MAXPLAYERS+1],
		g_bObjects	[MAXPLAYERS+1],
		g_bHasSound	[MAXPLAYERS+1],
		g_bLateLoad = false;

Handle 	g_hEnemiesCookie 	= INVALID_HANDLE,
		g_hObjectsCookie 	= INVALID_HANDLE,
		g_hOverlayEnemies 	= INVALID_HANDLE,
		g_hOverlayObjects 	= INVALID_HANDLE,
		g_hHasSound 		= INVALID_HANDLE;

int 	g_iOverlayEnemies	[MAXPLAYERS+1],
		g_iOverlayObjects	[MAXPLAYERS+1];

ConVar	g_cGlobal, g_cEnemiesGlobal, g_cObjectsGlobal, g_cSoundFXGlobal, 
		g_cTimerReset, g_cSoundFXVolume, g_cObserver;

public void OnPluginStart()
{	
	g_hEnemiesCookie 		= RegClientCookie("HM Enemies", 			"", CookieAccess_Protected);
	g_hObjectsCookie 		= RegClientCookie("HM Objects", 			"", CookieAccess_Protected);
	g_hHasSound 			= RegClientCookie("HM Soundfx", 			"", CookieAccess_Protected);
	g_hOverlayEnemies 		= RegClientCookie("HM Enemies Overlay",		"", CookieAccess_Protected);
	g_hOverlayObjects 		= RegClientCookie("HM Objects Overlay", 	"", CookieAccess_Protected);
	
	HookEvent("player_hurt", Event_PlayerHurt);

	HookEntityOutput("func_physbox", 				"OnHealthChanged", 	Hook_OnDamage);
	HookEntityOutput("func_physbox_multiplayer",	"OnHealthChanged", 	Hook_OnDamage);
	HookEntityOutput("func_breakable", 				"OnHealthChanged", 	Hook_OnDamage);
	HookEntityOutput("math_counter", 				"OutValue", 		Hook_OnDamageCounter);
	
	RegConsoleCmd("sm_hitmarker", 	Command_HM);
	RegConsoleCmd("sm_hitmarkers", 	Command_HM);
	RegConsoleCmd("sm_hm", 			Command_HM);
	RegConsoleCmd("sm_bhm", 		Command_HM);
	RegConsoleCmd("sm_hmarker", 	Command_HM);
	
	g_cGlobal 			= CreateConVar("sm_hitmarkers_enabled", 		"1", 		"1 = Enable the plugin | 0 = Disable the plugin (Default 1)");
	g_cEnemiesGlobal 	= CreateConVar("sm_hitmarkers_enemies", 		"1", 		"1 = Enable enemies hitmarker | 0 = Disable (Default 1)");
	g_cObjectsGlobal 	= CreateConVar("sm_hitmarkers_objects", 		"1", 		"1 = Enable objects hitmarker | 0 = Disable (Default 1)");
	g_cSoundFXGlobal 	= CreateConVar("sm_hitmarkers_soundfx", 		"1", 		"1 = Enable sound effects | 0 = Disable (Default 1)");
	g_cTimerReset 		= CreateConVar("sm_hitmarkers_resethm", 		"0.5", 		"Time in seconds to restart the hitmarker (hide it after shoot) (Default 0.5)");
	g_cObserver 		= CreateConVar("sm_hitmarkers_observer", 		"1", 		"Spectators can see hitmarkers and listen the sound effect when they're spectating a target? | 1 = Enabled | 0 = Disabled (Default 1)");
	g_cSoundFXVolume 	= CreateConVar("sm_hitmarkers_volume", 			"1.0", 		"Volume of the sound effect (Default/Max: 1.0)", _, true, 0.1, true, 1.0);
	
	LoadTranslations("hitmarkers.phrases");
	AutoExecConfig(true, "hitmarkers");	
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

//---------------------------------------
// Purpose: Voids
//---------------------------------------

public void OnMapStart()
{
	PrecacheSound(HitmarkerSoundEffect);

	PrecacheModel(HitmarkerOverlay1Vmt);
	PrecacheModel(HitmarkerOverlay2Vmt);
	PrecacheModel(HitmarkerOverlay3Vmt);
	PrecacheModel(HitmarkerOverlay4Vmt);
	PrecacheModel(HitmarkerOverlay5Vmt);
	PrecacheModel(HitmarkerOverlay6Vmt);
	PrecacheModel(HitmarkerOverlay7Vmt);

	AddFileToDownloadsTable(HitmarkerSoundEffectD);
	AddFileToDownloadsTable(HitmarkerOverlay1VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay2VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay3VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay4VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay5VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay6VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay7VtfD);
	AddFileToDownloadsTable(HitmarkerOverlay1Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay2Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay3Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay4Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay5Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay6Vmt);
	AddFileToDownloadsTable(HitmarkerOverlay7Vmt);
}

public void OnPluginEnd()
{
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i))
			{
				OnClientDisconnect(i);
			}
		}
	}

	Cleanup(true);
}

public void OnClientPutInServer(int client)
{
	if (AreClientCookiesCached(client))
	{
		ReadClientCookies(client);
	}
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void OnClientDisconnect(int client)
{
	SetClientCookies(client);
}

void Cleanup(bool bPluginEnd = false)
{
	if (bPluginEnd)
	{
		if (g_hEnemiesCookie != INVALID_HANDLE)
			CloseHandle(g_hEnemiesCookie);
		if (g_hObjectsCookie != INVALID_HANDLE)
			CloseHandle(g_hObjectsCookie);
		if (g_hHasSound != INVALID_HANDLE)
			CloseHandle(g_hHasSound);
		if (g_hOverlayEnemies != INVALID_HANDLE)
			CloseHandle(g_hOverlayEnemies);
		if (g_hOverlayObjects != INVALID_HANDLE)
			CloseHandle(g_hOverlayObjects);
	}
}

void ReadClientCookies(int client)
{
	char sBuffer[4];

	GetClientCookie(client, g_hEnemiesCookie, sBuffer, sizeof(sBuffer));
	g_bEnemies[client] = sBuffer[0] == '\0' ? true : view_as<bool>(StringToInt(sBuffer));

	GetClientCookie(client, g_hObjectsCookie, sBuffer, sizeof(sBuffer));
	g_bObjects[client] = sBuffer[0] == '\0' ? true : view_as<bool>(StringToInt(sBuffer));
	
	GetClientCookie(client, g_hHasSound, sBuffer, sizeof(sBuffer));
	g_bHasSound[client] = sBuffer[0] == '\0' ? true : view_as<bool>(StringToInt(sBuffer));

	GetClientCookie(client, g_hOverlayEnemies, sBuffer, sizeof(sBuffer));
	g_iOverlayEnemies[client] = (sBuffer[0] == '\0' ? 0 : StringToInt(sBuffer));
	
	GetClientCookie(client, g_hOverlayObjects, sBuffer, sizeof(sBuffer));
	g_iOverlayObjects[client] = (sBuffer[0] == '\0' ? 0 : StringToInt(sBuffer));
}

void SetClientCookies(int client)
{
	char sValue[4];

	Format(sValue, sizeof(sValue), "%i", g_bEnemies[client]);
	SetClientCookie(client, g_hEnemiesCookie, sValue);

	Format(sValue, sizeof(sValue), "%i", g_bObjects[client]);
	SetClientCookie(client, g_hObjectsCookie, sValue);
	
	Format(sValue, sizeof(sValue), "%i", g_bHasSound[client]);
	SetClientCookie(client, g_hHasSound, sValue);
	
	Format(sValue, sizeof(sValue), "%i", g_iOverlayEnemies[client]);
	SetClientCookie(client, g_hOverlayEnemies, sValue);
	
	Format(sValue, sizeof(sValue), "%i", g_iOverlayObjects[client]);
	SetClientCookie(client, g_hOverlayObjects, sValue);
}

void ShowOverlayEnemies(int client)
{
	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "%s%d.vtf", HitmarkerOverlay, g_iOverlayEnemies[client]);
	ClientCommand(client, "r_screenoverlay \"%s\"", sBuffer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!g_cObserver.BoolValue)
		{
			return;
		}

		if (!IsClientInGame(i) || !IsClientObserver(i))
			continue;

		int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		if (iObserverMode != 4 && iObserverMode != 5)
			continue;

		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != client)
			continue;

		ClientCommand(i, "r_screenoverlay \"%s\"", sBuffer);
		CreateTimer(GetConVarFloat(g_cTimerReset), Timer_RemoveOverlay, i);

		if(g_cSoundFXGlobal.IntValue >= 1)
		{
			EmitSoundToClient(i, HitmarkerSoundEffect, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, GetConVarFloat(g_cSoundFXVolume));
		}
	}
}

void ShowOverlayObjects(int client)
{
	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "%s%d.vtf", HitmarkerOverlay, g_iOverlayObjects[client]);
	ClientCommand(client, "r_screenoverlay \"%s\"", sBuffer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!g_cObserver.BoolValue)
		{
			return;
		}

		if (!IsClientInGame(i) || !IsClientObserver(i))
			continue;

		int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		if (iObserverMode != 4 && iObserverMode != 5)
			continue;

		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != client)
			continue;

		ClientCommand(i, "r_screenoverlay \"%s\"", sBuffer);
		CreateTimer(GetConVarFloat(g_cTimerReset), Timer_RemoveOverlay, i);

		if(g_cSoundFXGlobal.IntValue >= 1)
		{
			EmitSoundToClient(i, HitmarkerSoundEffect, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, GetConVarFloat(g_cSoundFXVolume));
		}
	}
}

void StopOverlay(int client, const char[] overlaypath)
{
    ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

//---------------------------------------
// Purpose: Menu & Command
//---------------------------------------

public Action Command_HM(int client, int args)
{
	if(!g_cGlobal.BoolValue)
	{
		CPrintToChat(client, PREFIX, "DISABLED");
		return Plugin_Handled;
	}

	HMMenu(client);
	return Plugin_Handled;
}

public void HMMenu(int client)
{
	Menu menu = new Menu(MenuHandler_HMenu, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	menu.ExitButton = true;
	SetMenuTitle(menu, "%t", "MENU_TITLE");
	AddMenuItem(menu, NULL_STRING, "Enemies");
	AddMenuItem(menu, NULL_STRING, "Objects");
	AddMenuItem(menu, NULL_STRING, "Sounds");
	AddMenuItem(menu, NULL_STRING, "Overlay1");
	AddMenuItem(menu, NULL_STRING, "Overlay2");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_HMenu(Menu menu, MenuAction action, int client, int param2)	
{	
	switch(action)	
	{	
		case MenuAction_End:	
		{	
			if(client != MenuEnd_Selected)	
				delete menu;	
		}	
		case MenuAction_Select:	
		{	
			switch(param2)	
			{	
				case 0:	
				{	
					g_bEnemies[client] = !g_bEnemies[client];	
					CPrintToChat(client, PREFIX, "ENEMIE", g_bEnemies[client] ? "{blue}Enabled" : "{darkred}Disabled");	
				}	
				case 1:	
				{	
					g_bObjects[client] = !g_bObjects[client];	
					CPrintToChat(client, PREFIX, "OBJECT", g_bObjects[client] ? "{blue}Enabled" : "{darkred}Disabled");	
				}	
				case 2:	
				{	
					g_bHasSound[client] = !g_bHasSound[client];	
					CPrintToChat(client, PREFIX, "SOUND", g_bHasSound[client] ? "{blue}Enabled" : "{darkred}Disabled");	
				}	
				case 3:	
				{	
					if(g_iOverlayEnemies[client] >= 6)	
					{	
						g_iOverlayEnemies[client] = 0;	
					}	
					else	
					{	
						g_iOverlayEnemies[client]++;	
					}	
					CPrintToChat(client, PREFIX, "OVERLAY_1", g_iOverlayEnemies[client]);	
				}	
				case 4:	
				{	
					if(g_iOverlayObjects[client] >= 6)	
					{	
						g_iOverlayObjects[client] = 0;	
					}	
					else	
					{	
						g_iOverlayObjects[client]++;	
					}	
					CPrintToChat(client, PREFIX, "OVERLAY_2", g_iOverlayObjects[client]);	
				}	
				default: return 0;	
			}	
			DisplayMenu(menu, client, MENU_TIME_FOREVER);	
		}	
		case MenuAction_DisplayItem:	
		{	
			char sBuffer[32];	
			switch(param2)	
			{	
				case 0:	
				{	
					Format(sBuffer, sizeof(sBuffer), "%t", "LINE_1", g_bEnemies[client] ? "Enabled" : "Disabled");	
				}	
				case 1:	
				{	
					Format(sBuffer, sizeof(sBuffer), "%t", "LINE_2", g_bObjects[client] ? "Enabled" : "Disabled");	
				}	
				case 2:	
				{	
					Format(sBuffer, sizeof(sBuffer), "%t", "LINE_3", g_bHasSound[client] ? "Enabled" : "Disabled");	
				}	
				case 3:	
				{	
					Format(sBuffer, sizeof(sBuffer), "%t", "LINE_4", g_iOverlayEnemies[client]);	
				}	
				case 4:	
				{	
					Format(sBuffer, sizeof(sBuffer), "%t", "LINE_5", g_iOverlayObjects[client]);	
				}	
			}	
			return RedrawMenuItem(sBuffer);	
		}	
	}	
	return 0;	
}

//---------------------------------------
// Purpose: Timers
//---------------------------------------

public Action Timer_RemoveOverlay(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		StopOverlay(client, "");
	}
}

//---------------------------------------
// Purpose: Hooks
//---------------------------------------

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(!client || !attacker || !g_cEnemiesGlobal.BoolValue)
	{
		return;
	}
		
	if(g_bEnemies[attacker])
	{
		ShowOverlayEnemies(attacker);
		CreateTimer(GetConVarFloat(g_cTimerReset), Timer_RemoveOverlay, attacker);
	}
	
	if(g_cSoundFXGlobal.IntValue >= 1 && g_bHasSound[attacker])
	{
		EmitSoundToClient(attacker, HitmarkerSoundEffect, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, GetConVarFloat(g_cSoundFXVolume));
	}
}

public void Hook_OnDamageCounter(const char[] output, int caller, int activator, float delay)
{
	if (!activator || !g_cObjectsGlobal.BoolValue)
	{
		return;
	}

	if(IsValidDamage(activator))
	{
		ShowOverlayObjects(activator);
		CreateTimer(GetConVarFloat(g_cTimerReset), Timer_RemoveOverlay, activator);
	}

	if(g_cSoundFXGlobal.IntValue >= 1 && IsValidSound(activator))
	{
		EmitSoundToClient(activator, HitmarkerSoundEffect, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, GetConVarFloat(g_cSoundFXVolume));
	}
}

public void Hook_OnDamage(const char[] output, int caller, int activator, float delay)
{
	if (!activator || !g_cObjectsGlobal.BoolValue)
	{
		return;
	}

	if(IsValidDamage(activator))
	{
		ShowOverlayObjects(activator);
		CreateTimer(GetConVarFloat(g_cTimerReset), Timer_RemoveOverlay, activator);
	}

	if(g_cSoundFXGlobal.IntValue >= 1 && IsValidSound(activator))
	{
		EmitSoundToClient(activator, HitmarkerSoundEffect, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, GetConVarFloat(g_cSoundFXVolume));
	}
}

bool IsValidDamage(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !g_bObjects[client] || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

bool IsValidSound(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !g_bHasSound[client] || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}