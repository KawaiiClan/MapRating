#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <shavit>

chatstrings_t gS_ChatStrings;

Handle g_hRatingDB = INVALID_HANDLE;
Handle g_cDisableRating;

Menu g_hBestMapsMenu;
Menu g_hWorstMapsMenu;

ArrayList g_aMapList;

int g_iRating[MAXPLAYERS + 1];
int g_iEditRating[MAXPLAYERS + 1];

bool g_bDisableRating[MAXPLAYERS + 1] = {false, ...};
bool g_bFavorite[MAXPLAYERS + 1] = {false, ...};

bool g_bMapChooser = false;

char g_sCurrentMap[PLATFORM_MAX_PATH];
float g_fCurrentMapAvgRating = 0.0;
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

	LoadTranslations("shavit-common.phrases");
	LoadTranslations("kawaii-maprating.phrases");

	g_bMapChooser = LibraryExists("shavit-mapchooser");
	
	g_aMapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if(g_bMapChooser)
		g_aMapList = Shavit_GetMapsArrayList();
	
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-mapchooser"))
	{
		g_bMapChooser = true;
		g_aMapList = Shavit_GetMapsArrayList();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-mapchooser"))
	{
		g_bMapChooser = false;
		g_aMapList.Clear();
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
	GetMapRatings();
	GetCurrentMapRating();
}

public void OnClientAuthorized(int client, const char[] auth)
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
	Format(Query, sizeof(Query), "SELECT Avg(rating), COUNT(*) FROM ratings WHERE map = '%s';", g_sCurrentMap);
	SQL_TQuery(g_hRatingDB, SQL_GetCurrentMapRating, Query);
}

public void SQL_GetCurrentMapRating(Handle owner, Handle hndl, const char[] error, any data)
{
	g_fCurrentMapAvgRating = 0.0;
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			g_fCurrentMapAvgRating = SQL_FetchFloat(hndl, 0);
			g_iCurrentMapRates = SQL_FetchInt(hndl, 1);
		}
	}
}

void GetMapRatings()
{
	char Query[255];
	Format(Query, sizeof(Query), "SELECT AVG(rating), COUNT(*), map FROM ratings GROUP BY map ORDER BY SUM(rating) DESC, COUNT(*) ASC LIMIT 50;");
	SQL_TQuery(g_hRatingDB, SQL_GetBestMapRatings, Query);
	
	Format(Query, sizeof(Query), "SELECT AVG(rating), COUNT(*), map FROM ratings GROUP BY map ORDER BY SUM(rating) ASC, COUNT(*) DESC LIMIT 50;");
	SQL_TQuery(g_hRatingDB, SQL_GetWorstMapRatings, Query);
}

public void SQL_GetBestMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hBestMapsMenu;
	g_hBestMapsMenu = new Menu(MapsMenuHandler);

	g_hBestMapsMenu.SetTitle("%T\n ", "TopRatedMaps", LANG_SERVER);
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			float fMapRating = SQL_FetchFloat(hndl, 0);
			int iMapRates = SQL_FetchInt(hndl, 1);
			char sMap[255];
			SQL_FetchString(hndl, 2, sMap, sizeof(sMap))
			
			char buf[255];
			Format(buf, sizeof(buf), "(%.1f) %s (%i %T)", fMapRating, sMap, iMapRates, iMapRates > 1 ? "Votes" : "Vote", LANG_SERVER);
			
			g_hBestMapsMenu.AddItem(sMap, buf, ITEMDRAW_DEFAULT);
		}
	}
}

public void SQL_GetWorstMapRatings(Handle owner, Handle hndl, const char[] error, any data)
{
	delete g_hWorstMapsMenu;
	g_hWorstMapsMenu = new Menu(MapsMenuHandler);

	g_hWorstMapsMenu.SetTitle("%T\n ", "WorstRatedMaps", LANG_SERVER);
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			float fMapRating = SQL_FetchFloat(hndl, 0);
			int iMapRates = SQL_FetchInt(hndl, 1);
			char sMap[255];
			SQL_FetchString(hndl, 2, sMap, sizeof(sMap))
			
			char buf[255];
			Format(buf, sizeof(buf), "(%.1f) %s (%i %T)", fMapRating, sMap, iMapRates, iMapRates > 1 ? "Votes" : "Vote", LANG_SERVER);
			
			g_hWorstMapsMenu.AddItem(sMap, buf, ITEMDRAW_DEFAULT);
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

	g_iEditRating[data] = g_iRating[data];
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
	Menu menu = new Menu(MapsMenuHandler);

	menu.SetTitle("%T\n ", "FavoriteMaps", data);
	char sDisplay[PLATFORM_MAX_PATH];
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sDisplay, sizeof(sDisplay))
			
			menu.AddItem(sDisplay, sDisplay, ITEMDRAW_DEFAULT);
		}
	}
	else
	{
		FormatEx(sDisplay, sizeof(sDisplay), "%T", "NoneFound", data)
		menu.AddItem("none", sDisplay, ITEMDRAW_DISABLED);		
	}
	
	menu.Display(data, MENU_TIME_FOREVER);
}

public int MapsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sMap[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sMap, sizeof(sMap));

		FakeClientCommand(param1, "sm_nominate %s", sMap);
	}

	return 0;
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
	Shavit_PrintToChat(client, "%T", g_bFavorite[client] ? "MapFavoritesAdded" : "MapFavoritesRemoved", client,
		gS_ChatStrings.sVariable, g_sCurrentMap, gS_ChatStrings.sText, g_bFavorite[client] ? gS_ChatStrings.sVariable : gS_ChatStrings.sWarning, gS_ChatStrings.sText, gS_ChatStrings.sVariable);
	
	return Plugin_Handled;
}

public Action OpenRateMenu(int client, bool fromFinish)
{
	Panel hPanel = CreatePanel();
	char sDisplay[128];
	
	hPanel.SetTitle(g_sCurrentMap);

	char sRating[16];
	
	for (int i = 1; i <= 5; i++)
	{
		FormatEx(sRating, sizeof(sRating), "%s%s", sRating, i <= g_iEditRating[client] ? "★":"☆")
	}
	
	if(g_iCurrentMapRates == 0)
	{
		FormatEx(sDisplay, sizeof(sDisplay), "%T", "NoRatesOnMap", client);	
	}
	else
	{
		FormatEx(sDisplay, sizeof(sDisplay), "%T: %.1f / 5.0 (%d %T)", 
				"AvgRating", client, g_fCurrentMapAvgRating,
				g_iCurrentMapRates, g_iCurrentMapRates > 1 ? "Votes":"Vote", client);		
	}

	FormatEx(sDisplay, sizeof(sDisplay), "%s\n \n%T\n%T: %s\n ", sDisplay, "RatingQuestion", client, "PlayerRating", client, sRating);		

	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);

	FormatEx(sDisplay, sizeof(sDisplay), "%T", "CommitRating", client);
	hPanel.DrawItem(sDisplay, (g_iEditRating[client] == 0 || g_iEditRating[client] == g_iRating[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_CONTROL);

	FormatEx(sDisplay, sizeof(sDisplay), "%T", "ChangeRating", client);
	hPanel.DrawItem(sDisplay);
	
	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "[%T] %T", g_bFavorite[client] == true ? "ItemEnabled" : "ItemDisabled", client, "AddToFavorites", client);
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "[%T] %T", !g_bDisableRating[client] ?  "ItemEnabled" : "ItemDisabled", client, "OpenRateMenuOnFinish", client);
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);
	
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
						SetClientRating(client);

						OpenRateMenu(client, false);
					}
				}
				case 2:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
						
						if(++g_iEditRating[client] > 5)
							g_iEditRating[client] = 1;
						
						OpenRateMenu(client, false);
					}
				}
				case 3:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
						g_bFavorite[client] = !g_bFavorite[client];
						SetClientFavorite(client);
						OpenRateMenu(client, false);
					}
				}
				case 4:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
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

	return 0;
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
	int iFirstRate = g_iRating[client] <= 0 ? 1:0;
	float fRateDiff = float(g_iEditRating[client] - g_iRating[client]);

	g_iRating[client] = g_iEditRating[client];

	g_fCurrentMapAvgRating = ((g_fCurrentMapAvgRating * float(g_iCurrentMapRates)) + fRateDiff) / float(g_iCurrentMapRates + iFirstRate);
	g_iCurrentMapRates += iFirstRate;

	int iSteamID = GetSteamAccountID(client);
	char Query[500];
	Format(Query, sizeof(Query), "INSERT INTO ratings (map, auth, rating) VALUES('%s', %i, %i) ON DUPLICATE KEY UPDATE rating = VALUES(rating);", g_sCurrentMap, iSteamID, g_iRating[client]);
	SQL_TQuery(g_hRatingDB, SQL_ErrorCheckCallBack, Query);

	Shavit_PrintToChat(client, "%T", "RatingThanks", client, gS_ChatStrings.sVariable);
	
	GetMapRatings();
}

void SetClientFavorite(int client)
{
	int iSteamID = GetSteamAccountID(client);
	char Query[500];
	
	if(g_bFavorite[client])
		Format(Query, sizeof(Query), "INSERT INTO favorites (map, auth) VALUES('%s', %i) ON DUPLICATE KEY UPDATE auth = VALUES(auth);", g_sCurrentMap, iSteamID);
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
