#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <shavit>

chatstrings_t gS_ChatStrings;

Handle g_hRatingDB = INVALID_HANDLE;
Handle cDisableRating;

Menu g_hTopMapsMenu;
Menu g_hLowMapsMenu;

int g_iRating[MAXPLAYERS + 1];
bool g_bDisableRating[MAXPLAYERS + 1] = {false, ...};
char g_sCurrentMap[255];
int g_iCurrentMapRating = 0;
int g_iCurrentMapRates = 0;

public Plugin myinfo =
{
	name = "Kawaii-MapRating",
	author = "olivia",
	description = "Allow players to rate maps",
	version = "c:",
	url = "https://KawaiiClan.com"
}

public void OnPluginStart()
{
	cDisableRating = RegClientCookie("noRating", "Disable rating survey", CookieAccess_Private);
	
	RegConsoleCmd("sm_rate", Command_Rate, "Opens the map rating menu");
	RegConsoleCmd("sm_rating", Command_Rate, "Opens the map rating menu");
	RegConsoleCmd("sm_topmaps", OpenTopMapsMenu, "Opens the top maps menu");
	RegConsoleCmd("sm_toprated", OpenTopMapsMenu, "Opens the top maps menu");
	RegConsoleCmd("sm_worstmaps", OpenLowMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_bottommaps", OpenLowMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_worstrated", OpenLowMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_lowrated", OpenLowMapsMenu, "Opens the worst maps menu");
	
	Shavit_OnChatConfigLoaded();
	
	InitRatingDB(g_hRatingDB);
	
	GetMapRatings();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
}

public void OnMapStart()
{
	GetLowercaseMapName(g_sCurrentMap);
	GetCurrentMapRating();
}

public void OnClientPutInServer(int client)
{
	GetClientRating(client);
	char cookie[12];
	GetClientCookie(client, cDisableRating, cookie, sizeof(cookie))
	g_bDisableRating[client] = view_as<bool>(StringToInt(cookie));
}

public Action InitRatingDB(Handle &DbHNDL)
{
	char Error[255];
	
	DbHNDL = SQL_Connect("maprating", true, Error, sizeof(Error));
	if(DbHNDL == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	else
	{
		SQL_TQuery(g_hRatingDB, SQL_ErrorCheckCallBack, "CREATE TABLE IF NOT EXISTS `ratings` (`map` varchar(100) NOT NULL, `auth` int NOT NULL, `rating` int NOT NULL, UNIQUE KEY `unique_index` (`map`,`auth`)) ENGINE=INNODB;");
	}
	
	return Plugin_Handled;
}

void GetCurrentMapRating()
{
	char Query[255];
	Format(Query, sizeof(Query), "SELECT SUM(rating), COUNT(*) FROM ratings WHERE map = '%s';", g_sCurrentMap);
	SQL_TQuery(g_hRatingDB, SQL_GetCurrentMapRating, Query);
}

public void SQL_GetCurrentMapRating(Handle owner, Handle hndl, const char[] error, any data)
{
	g_iCurrentMapRating = 0;
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			g_iCurrentMapRating = SQL_FetchInt(hndl, 0);
			g_iCurrentMapRates = SQL_FetchInt(hndl, 1);
		}
	}
}

void GetMapRatings()
{
	char Query[255];
	Format(Query, sizeof(Query), "SELECT SUM(rating), COUNT(*), map FROM ratings GROUP BY map ORDER BY SUM(rating) DESC, COUNT(*) ASC LIMIT 50;");
	SQL_TQuery(g_hRatingDB, SQL_GetTopMapRatings, Query);
	
	Format(Query, sizeof(Query), "SELECT SUM(rating), COUNT(*), map FROM ratings GROUP BY map ORDER BY SUM(rating) ASC, COUNT(*) DESC LIMIT 50;");
	SQL_TQuery(g_hRatingDB, SQL_GetLowMapRatings, Query);
}

public void SQL_GetTopMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hTopMapsMenu;
	g_hTopMapsMenu = new Menu(MapsMenuHandler);

	g_hTopMapsMenu.SetTitle("Top 50 Rated Maps \n ");
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			int iMapRating = SQL_FetchInt(hndl, 0);
			int iMapRates = SQL_FetchInt(hndl, 1);
			char sMap[255];
			SQL_FetchString(hndl, 2, sMap, sizeof(sMap))
			
			char buf[255];
			Format(buf, sizeof(buf), "(%s%i) %s (%i Vote%s)", iMapRating > 0 ? "+" : "", iMapRating, sMap, iMapRates, iMapRating > 1 ? "s" : "");
			
			g_hTopMapsMenu.AddItem(sMap, buf, ITEMDRAW_DISABLED);
		}
	}
}

public void SQL_GetLowMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hLowMapsMenu;
	g_hLowMapsMenu = new Menu(MapsMenuHandler);

	g_hLowMapsMenu.SetTitle("Worst 50 Rated Maps \n ");
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			int iMapRating = SQL_FetchInt(hndl, 0);
			int iMapRates = SQL_FetchInt(hndl, 1);
			char sMap[255];
			SQL_FetchString(hndl, 2, sMap, sizeof(sMap))
			
			char buf[255];
			Format(buf, sizeof(buf), "(%s%i) %s (%i Vote%s)", iMapRating > 0 ? "+" : "", iMapRating, sMap, iMapRates, iMapRating > 1 ? "s" : "");
			
			g_hLowMapsMenu.AddItem(sMap, buf, ITEMDRAW_DISABLED);
		}
	}
}

void GetClientRating(int client)
{
	char Query[255];
	
	Format(Query, sizeof(Query), "SELECT rating FROM ratings WHERE auth = '%i' AND map = '%s';", GetSteamAccountID(client), g_sCurrentMap);
	
	SQL_TQuery(g_hRatingDB, SQL_GetClientRating, Query, client);
}

public void SQL_GetClientRating(Handle owner, Handle hndl, const char[] error, int data)
{
	g_iRating[data] = 0;
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			g_iRating[data] = SQL_FetchInt(hndl, 0);
		}
	}
}

public Action OpenTopMapsMenu(int client, int args)
{
	g_hTopMapsMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action OpenLowMapsMenu(int client, int args)
{
	g_hLowMapsMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MapsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	//TODO Create nominate forward to allow nominations from this menu
	/*if(action == MenuAction_Select)
	{
		char sMap[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sMap, sizeof(sMap));

		Nominate(param1, sMap);
	}*/

	return Plugin_Handled;
}

public Action Command_Rate(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "This command may be only performed in game");
	}

	OpenRateMenu(client, false);
	return Plugin_Handled;
}

public Action OpenRateMenu(int client, bool fromFinish)
{
	Panel hPanel = CreatePanel();
	char sDisplay[128];
	char s[8];
	IntToString(g_iCurrentMapRates, s, sizeof(s));
	
	hPanel.SetTitle(g_sCurrentMap);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Rating: %s%i %s%s%s%s \n \nIs this a good map?",
						g_iCurrentMapRating > 0 ? "+" : "",
						g_iCurrentMapRating,
						g_iCurrentMapRates == 0 ? "" : "(",
						g_iCurrentMapRates == 0 ? "" : s,
						g_iCurrentMapRates == 0 ? "" : " Vote",
						g_iCurrentMapRates == 0 ? "" : (g_iCurrentMapRates > 1 ? "s)" : ")"));
	
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "%sYes", fromFinish ? "" : (g_iRating[client] == 1 ? "[X] " : "[  ] "));
	hPanel.DrawItem(sDisplay, g_iRating[client] == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_CONTROL);
	
	FormatEx(sDisplay, sizeof(sDisplay), "%sNo", fromFinish ? "" : (g_iRating[client] == -1 ? "[X] " : "[  ] "));
	hPanel.DrawItem(sDisplay, g_iRating[client] == -1 ? ITEMDRAW_DISABLED : ITEMDRAW_CONTROL);
	
	if(fromFinish)
	{
		SetPanelCurrentKey(hPanel, 4);
		
		hPanel.DrawItem("Don't ask again :c", ITEMDRAW_CONTROL);
	
		hPanel.DrawItem("", ITEMDRAW_SPACER);
	}
	else
	{
		FormatEx(sDisplay, 64, "[%s] Ask on unrated map finish", g_bDisableRating[client] ? "  " : "X");
		hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
		hPanel.DrawItem("", ITEMDRAW_SPACER);
	}
	
	SetPanelCurrentKey(hPanel, 10);
	
	hPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	
	hPanel.Send(client, RateMenuHandler, MENU_TIME_FOREVER);
	CloseHandle(hPanel);

	return Plugin_Handled;
}

public int RateMenuHandler(Handle hPanel, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			if(IsValidClient(client))
			{
				EmitSoundToClient(client, "buttons/combine_button7.wav");
			}
			CloseHandle(hPanel);
		}
		case MenuAction_Cancel: 
		{
			if(IsValidClient(client))
			{
				EmitSoundToClient(client, "buttons/combine_button7.wav");
			}
			CloseHandle(hPanel);
		}
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 1:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
						g_iRating[client] = 1;
						SetClientRating(client);
					}
				}
				case 2:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
						g_iRating[client] = -1;
						SetClientRating(client);
					}
				}
				case 3:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/combine_button7.wav");
						g_bDisableRating[client] = !g_bDisableRating[client];
						char s[2];
						IntToString(view_as<int>(g_bDisableRating[client]), s, sizeof(s));
						SetClientCookie(client, cDisableRating, s);
						OpenRateMenu(client, false);
					}
				}
				case 4:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/combine_button7.wav");
						g_bDisableRating[client] = !g_bDisableRating[client];
						char s[2];
						IntToString(view_as<int>(g_bDisableRating[client]), s, sizeof(s));
						SetClientCookie(client, cDisableRating, s);
						Shavit_PrintToChat(client, "No longer showing %s!rate %smenu on map finish!", gS_ChatStrings.sVariable, gS_ChatStrings.sText)
					}
				}
				case 10:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/combine_button7.wav");
					}
				}
			}
			CloseHandle(hPanel);
		}
	}
	return Plugin_Handled;
}

public Action Shavit_OnFinishMessage(int client, bool &everyone, timer_snapshot_t snapshot, int overwrite, int rank, char[] message, int maxlen)
{
	if(!g_bDisableRating[client] && g_iRating[client] == 0)
	{
		OpenRateMenu(client, true);
	}
	return Plugin_Continue;
}

void SetClientRating(int client)
{
	int iSteamID = GetSteamAccountID(client);
	char Query[500];
	Format(Query, sizeof(Query), "INSERT INTO ratings (map, auth, rating) VALUES('%s', %i, %i) ON DUPLICATE KEY UPDATE rating = VALUES(rating);", g_sCurrentMap, iSteamID, g_iRating[client]);
	SQL_TQuery(g_hRatingDB, SQL_ErrorCheckCallBack, Query);
	Shavit_PrintToChat(client, "Thanks for rating the map! Change your rating with %s!rate", gS_ChatStrings.sVariable);
	GetCurrentMapRating();
	GetMapRatings();
}

public void SQL_ErrorCheckCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("Query failed! %s", error);
	}
}
