#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <shavit>

chatstrings_t gS_ChatStrings;

Handle g_hRatingDB = INVALID_HANDLE;
Handle g_cDisableRating;

Menu g_hBestMapsMenu;
Menu g_hWorstMapsMenu;

int g_iRating[MAXPLAYERS + 1];
bool g_bDisableRating[MAXPLAYERS + 1] = {false, ...};
bool g_bFavorite[MAXPLAYERS + 1] = {false, ...};
char g_sCurrentMap[255];
int g_iCurrentMapRating = 0;
int g_iCurrentMapRates = 0;

public Plugin myinfo =
{
	name = "Kawaii-MapRating",
	author = "olivia",
	description = "Allow players to rate and favorite maps",
	version = "c:",
	url = "https://KawaiiClan.com"
}

public void OnPluginStart()
{
	g_cDisableRating = RegClientCookie("noRating", "Disable rating survey", CookieAccess_Private);
	
	RegConsoleCmd("sm_rate", Command_Rate, "Opens the map rating menu");
	RegConsoleCmd("sm_ratemap", Command_Rate, "Opens the map rating menu");
	RegConsoleCmd("sm_rating", Command_Rate, "Opens the map rating menu");
	RegConsoleCmd("sm_favorite", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_favoritemap", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_unfavorite", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_fav", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_favmap", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_unfav", Command_Favorite, "Add/remove a map to your favorites list");
	RegConsoleCmd("sm_favorites", Command_OpenFavoritesMenu, "Open your favorites list");
	RegConsoleCmd("sm_favoritemaps", Command_OpenFavoritesMenu, "Open your favorites list");
	RegConsoleCmd("sm_favs", Command_OpenFavoritesMenu, "Open your favorites list");
	RegConsoleCmd("sm_favmaps", Command_OpenFavoritesMenu, "Open your favorites list");
	RegConsoleCmd("sm_topmaps", Command_OpenBestMapsMenu, "Opens the best maps menu");
	RegConsoleCmd("sm_bestmaps", Command_OpenBestMapsMenu, "Opens the best maps menu");
	RegConsoleCmd("sm_toprated", Command_OpenBestMapsMenu, "Opens the best maps menu");
	RegConsoleCmd("sm_worstmaps", Command_OpenWorstMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_bottommaps", Command_OpenWorstMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_worstrated", Command_OpenWorstMapsMenu, "Opens the worst maps menu");
	RegConsoleCmd("sm_lowrated", Command_OpenWorstMapsMenu, "Opens the worst maps menu");
	
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
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
}

public void OnMapStart()
{
	GetLowercaseMapName(g_sCurrentMap);
	GetCurrentMapRating();
}

public void OnClientPutInServer(int client)
{
	GetClientRating(client);
	GetClientFavorite(client);
	char cookie[12];
	GetClientCookie(client, g_cDisableRating, cookie, sizeof(cookie))
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
		SQL_TQuery(g_hRatingDB, SQL_ErrorCheckCallBack, "CREATE TABLE IF NOT EXISTS `favorites` (`map` varchar(100) NOT NULL, `auth` int NOT NULL, UNIQUE KEY `unique_index` (`map`,`auth`)) ENGINE=INNODB;");
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
	SQL_TQuery(g_hRatingDB, SQL_GetBestMapRatings, Query);
	
	Format(Query, sizeof(Query), "SELECT SUM(rating), COUNT(*), map FROM ratings GROUP BY map ORDER BY SUM(rating) ASC, COUNT(*) DESC LIMIT 50;");
	SQL_TQuery(g_hRatingDB, SQL_GetWorstMapRatings, Query);
}

public void SQL_GetBestMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hBestMapsMenu;
	g_hBestMapsMenu = new Menu(MapsMenuHandler);

	g_hBestMapsMenu.SetTitle("Top 50 Rated Maps \n ");
	
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
			
			g_hBestMapsMenu.AddItem(sMap, buf, ITEMDRAW_DISABLED);
		}
	}
}

public void SQL_GetWorstMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hWorstMapsMenu;
	g_hWorstMapsMenu = new Menu(MapsMenuHandler);

	g_hWorstMapsMenu.SetTitle("Worst 50 Rated Maps \n ");
	
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
			
			g_hWorstMapsMenu.AddItem(sMap, buf, ITEMDRAW_DISABLED);
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

void GetClientFavorite(int client)
{
	char Query[255];
	
	Format(Query, sizeof(Query), "SELECT * FROM favorites WHERE auth = '%i' AND map = '%s';", GetSteamAccountID(client), g_sCurrentMap);
	
	SQL_TQuery(g_hRatingDB, SQL_GetClientFavorite, Query, client);
}

public void SQL_GetClientFavorite(Handle owner, Handle hndl, const char[] error, int data)
{
	if(SQL_GetRowCount(hndl) > 0)
		g_bFavorite[data] = true;
	else
		g_bFavorite[data] = false;
}

public Action Command_OpenBestMapsMenu(int client, int args)
{
	g_hBestMapsMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_OpenWorstMapsMenu(int client, int args)
{
	g_hWorstMapsMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_OpenFavoritesMenu(int client, int args)
{
	GetClientFavorites(client);
	return Plugin_Handled;
}

void GetClientFavorites(client)
{
	char Query[255];
	
	Format(Query, sizeof(Query), "SELECT map FROM favorites WHERE auth = '%i' ORDER BY map ASC;", GetSteamAccountID(client));
	
	SQL_TQuery(g_hRatingDB, SQL_GetClientFavorites, Query, client);
}

public void SQL_GetClientFavorites(Handle owner, Handle hndl, const char[] error, any data)
{
	menu = new Menu(MapsMenuHandler);

	menu.SetTitle("Favorite Maps \n ");
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			char sMap[255];
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap))
			
			menu.AddItem(sMap, sMap, ITEMDRAW_DISABLED);
		}
	}
	else
		menu.AddItem("none", "None found", ITEMDRAW_DISABLED);
	
	menu.Display(client, MENU_TIME_FOREVER);
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

public Action Command_Favorite(int client, int args)
{
	if(client == 0)
		ReplyToCommand(client, "This command may be only performed in game");

	g_bFavorite[client] = !g_bFavorite[client];
	SetClientFavorite(client);
	Shavit_PrintToChat(client, "Map %s%s %shas been %s%s %sfrom your %s!favorites", gS_ChatStrings.sVariable, g_sCurrentMap, gS_ChatStrings.sText, g_bFavorite[client] ? gS_ChatStrings.sVariable : gS_ChatStrings.sWarning, g_bFavorite[client] ? "added" : "removed", gS_ChatStrings.sText, gS_ChatStrings.sVariable);
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
	
	hPanel.DrawItem("", ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "%sFavorite Map", g_bFavorite[client] == true ? "[X] " : "[  ] ");
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
	hPanel.DrawItem("", ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "%sOpen !rate menu on unrated map finish", g_bDisableRating[client] ? "[  ] " : "[X] ");
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
	hPanel.DrawItem("", ITEMDRAW_RAWLINE);
	
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
						EmitSoundToClient(client, "buttons/button14.wav");
						g_bFavorite[client] = !g_bFavorite[client];
						SetClientFavorite(client);
						OpenRateMenu(client);
					}
				}
				case 4:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/combine_button14.wav");
						g_bDisableRating[client] = !g_bDisableRating[client];
						char s[2];
						IntToString(view_as<int>(g_bDisableRating[client]), s, sizeof(s));
						SetClientCookie(client, g_cDisableRating, s);
						OpenRateMenu(client, false);
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
	if(snapshot.iTimerTrack == 0 && !g_bDisableRating[client] && g_iRating[client] == 0)
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

void SetClientFavorite(int client)
{
	int iSteamID = GetSteamAccountID(client);
	char Query[500];
	
	if(g_bFavorite[client])
		Format(Query, sizeof(Query), "INSERT INTO favorites (map, auth) VALUES('%s', %i);", g_sCurrentMap, iSteamID);
	else
		Format(Query, sizeof(Query), "DELETE FROM favorites WHERE map = '%s' AND auth = %i;", g_sCurrentMap, iSteamID);
		
	SQL_TQuery(g_hRatingDB, SQL_ErrorCheckCallBack, Query);
}

public void SQL_ErrorCheckCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("Query failed! %s", error);
	}
}
