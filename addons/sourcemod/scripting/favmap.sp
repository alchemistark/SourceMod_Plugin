#include <sourcemod>

new Handle:v_favcfg = INVALID_HANDLE;
new Handle:v_ngcfg = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "FavMap",
	author = "AMG",
	description = "現在のマップを指定のmapcycleに追加・削除、選択NGのマップリストに追加・削除する",
	version = "1.0",
	url = ""
}

/*
機能追加予定

マップリスト更新(マップ追加時)
開始したマップがNGだったら即次のマップへ


*/

//プラグイン起動時
public OnPluginStart(){
	//cmd
	RegAdminCmd("sm_favmap", Cmd_favmap, 0, "現在のマップをお気に入りに追加");
	RegAdminCmd("sm_favmap_del", Cmd_favmap_del, 0, "現在のマップをお気に入りから削除");
	//RegAdminCmd("sm_ngmap", Cmd_ngmap, 0, "現在のマップを禁止リストに追加");
	//RegAdminCmd("sm_ngmap_del", Cmd_ngmap_del, 0, "禁止リストから指定のマップを禁止解除する");
	//RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//cvar	
	v_favcfg = CreateConVar("sm_favmap_list", "cfg/mapcycle_fav.txt", "お気に入りマップサイクル");
	v_ngcfg = CreateConVar("sm_ngmap_list", "cfg/mapcycle_ng.txt", "禁止マップサイクル");
	
	//eventhook
	HookEvent("teamplay_round_active", OnRoundStart);
}

/*デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	ServerCommand("sm plugins reload favmap");
	return false;
}
*/

//マップをリストに追加
public Action:Cmd_favmap(client, args){

	/*
	コマンドに"ng"が付加されている場合、NGマップとして処理する
	*/

	new String:strArg[3];
	new iFlag = 0;
	GetCmdArgString(strArg,sizeof(strArg));
	
	if(StrEqual(strArg,"ng")){
		//NG時動作フラグを立てる
		iFlag = 1;
	}
	
	new String:strCfg[PLATFORM_MAX_PATH];
	
	if(iFlag == 0){
		GetConVarString(v_favcfg,strCfg,sizeof(strCfg));
	}
	else if(iFlag == 1){
		GetConVarString(v_ngcfg,strCfg,sizeof(strCfg));
	}
	
	new Handle:hFile = OpenFile(strCfg,"a+");
	
	if(hFile == INVALID_HANDLE){
		PrintToServer("[FavMap]ERROR:(Cmd_favmap)ファイルの読み込みに失敗しました。");
	}
	
	new String:strMap[PLATFORM_MAX_PATH];
	new String:strLine[PLATFORM_MAX_PATH];
	
	GetCurrentMap(strMap,sizeof(strMap));
	
	while(!IsEndOfFile(hFile)){
		ReadFileLine(hFile,strLine,sizeof(strLine));
		ReplaceString(strLine,sizeof(strLine),"\n","");
		if(StrEqual(strMap,strLine)){
			if(iFlag == 0){
				PrintToChat(client,"[FavMap]ERROR:マップは既にお気に入り済みです。");
			}
			else if(iFlag == 1){
				PrintToChat(client,"[FavMap]ERROR:マップは既にNG登録済みです。");
			}
			CloseHandle(hFile);
			return false;
		}
	}
	WriteFileLine(hFile,"%s",strMap);
	
	if(iFlag == 0){
		PrintToChat(client,"[FavMap]%sをお気に入りマップに追加しました。",strMap);
	}
	else if(iFlag == 1){
		PrintToChat(client,"[FavMap]%sをNGマップに追加しました。",strMap);
	}

	CloseHandle(hFile);
}

//マップをリストから削除
public Action:Cmd_favmap_del(client, args){

	/*
	コマンドに"ng"が付加されている場合、NGマップとして処理する
	*/

	new String:strArg[3];
	new iFlag = 0;
	GetCmdArgString(strArg,sizeof(strArg));
	
	if(StrEqual(strArg,"ng")){
		//NG時動作フラグを立てる
		iFlag = 1;
	}
	
	new String:strCfg[PLATFORM_MAX_PATH];
	
	if(iFlag == 0){
		GetConVarString(v_favcfg,strCfg,sizeof(strCfg));
	}
	else if(iFlag == 1){
		GetConVarString(v_ngcfg,strCfg,sizeof(strCfg));
	}	
	
	new Handle:hFile = OpenFile(strCfg,"r");
	
	if(hFile == INVALID_HANDLE){
		PrintToServer("[FavMap]ERROR:ファイルの読み込みに失敗しました。");
	}

	new Handle:menu_fav_del = CreateMenu(Menu_FavDEL);
	
	if(iFlag == 0){
		SetMenuTitle(menu_fav_del, "delete fav map");
	}
	else if(iFlag == 1){
		SetMenuTitle(menu_fav_del, "delete NG map");
	}
	
	//メニュー作成処理
	new String:strMap[255];
	
	while(!IsEndOfFile(hFile)){
	
		ReadFileLine(hFile,strMap,sizeof(strMap));
		ReplaceString(strMap,sizeof(strMap),"\n","");
		
		//メニュー項目を作成
		if(StrEqual(strMap,"") == false){
			AddMenuItem(menu_fav_del, strCfg, strMap, ITEMDRAW_DEFAULT);
		}
		strMap = "";
	}

	//使い終わったので閉じる
	CloseHandle(hFile);
	
	//ファイルが空の場合メニューができない
	if(GetMenuItemCount(menu_fav_del) == 0){
		if(iFlag == 0){
			PrintToChat(client,"[FavMap]ERROR:お気に入りマップがありません。");
		}
		else if(iFlag == 1){
			PrintToChat(client,"[FavMap]ERROR:NGマップがありません。");
		}
		//CloseHandle(hFile_tmp);
		return false;
	}
	
	//表示処理へ
	DisplayMenu(menu_fav_del,client,MENU_TIME_FOREVER);

}

//マップ削除メニュー処理
public Menu_FavDEL(Handle:menu, MenuAction:action, param1, param2){

	switch(action){
		case MenuAction_Select:{
			new String:strCfg[255];
			GetMenuItem(menu, param2, strCfg, sizeof(strCfg));
			Cmd_DelMap(param1, param2, strCfg);
		}
		//メニュー処理が終了した
		case MenuAction_End:{
			CloseHandle(menu);	//終了したらハンドルを閉じておく
		}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}

//マップ削除処理
public Cmd_DelMap(int client, int iLine, String:strCfg[]){
	new String:strCfg_tmp[PLATFORM_MAX_PATH];
	
	Format(strCfg_tmp,sizeof(strCfg_tmp),"%s_tmp",strCfg);
	
	new Handle:hFile = OpenFile(strCfg,"r");
	new Handle:hFile_tmp = OpenFile(strCfg_tmp,"w");
	
	if(hFile == INVALID_HANDLE){
		PrintToServer("[FavMap]ERROR:(DelMap)ファイルの読み込みに失敗しました。");
		return false;
	}
	
	new i=0;
	new String:strMap[255];
	
	while(!IsEndOfFile(hFile)){
		ReadFileLine(hFile,strMap,sizeof(strMap));
		ReplaceString(strMap,sizeof(strMap),"\n","");
		if(i != iLine){
			if(StrEqual(strMap,"") == false){
				WriteFileLine(hFile_tmp,"%s",strMap);
			}
		}
		else{
			PrintToChat(client,"[FavMap]%sをリストから削除しました。",strMap);
		}
		strMap = "";
		i++;
	}
	
	CloseHandle(hFile);
	CloseHandle(hFile_tmp);
	
	DeleteFile(strCfg);
	RenameFile(strCfg,strCfg_tmp);
}

//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	//現在のマップ及びNextMapがNGリストに登録されていないか確認する
	Cmd_CheckMap();
}

//マップのチェック処理
public Cmd_CheckMap(){

	new String:strCfg[PLATFORM_MAX_PATH];
	new String:strMap[PLATFORM_MAX_PATH];
	new String:strLine[PLATFORM_MAX_PATH];
	new String:strNext[PLATFORM_MAX_PATH];
	GetConVarString(v_ngcfg,strCfg,sizeof(strCfg));
	
	new Handle:hFile = OpenFile(strCfg,"r");

	if(hFile == INVALID_HANDLE){
		PrintToServer("[FavMap]ERROR:(CheckMap)ファイルの読み込みに失敗しました。もしくはNGリストがありません。");
		return false;
	}
	
	//NextMapの確認と修正
	//ラウンドが終了しない、NEXTが無い場合はfalseが返ってくる
	GetNextMap(strNext,sizeof(strNext));
	
	GetCurrentMap(strMap,sizeof(strMap));

	while(!IsEndOfFile(hFile)){
		strLine = "";
		ReadFileLine(hFile,strLine,sizeof(strLine));
		ReplaceString(strLine,sizeof(strLine),"\n","");
		if(StrEqual(strMap,strLine)){
			//今居るマップはNGリストに登録されている
			PrintHintTextToAll("[FavMap] このマップはNGリストに登録されています\nクソマップの可能性が高いと思われます…");
		}
		if(StrEqual(strNext,strLine)){
			//NextMapがNGリストにある
			Cmd_NextMap(strNext);
		}
	}
	
	CloseHandle(hFile);
}

//NextMap変更処理
public Cmd_NextMap(String:strNext[]){

	new String:strCfg[PLATFORM_MAX_PATH];
	new String:strLine[PLATFORM_MAX_PATH];
	new Handle:v_cycle = FindConVar("mapcyclefile");
	
	GetConVarString(v_cycle,strCfg,sizeof(strCfg));
	Format(strCfg,sizeof(strCfg),"cfg/%s",strCfg);
	
	new Handle:hFile = OpenFile(strCfg,"r");
	
	if(hFile == INVALID_HANDLE){
		PrintToServer("[FavMap]ERROR:(Cmd_NextMap)ファイルの読み込みに失敗しました。");
		return false;
	}
	
	SetNextMap("");
	
	while(!IsEndOfFile(hFile)){
		strLine = "";
		ReadFileLine(hFile,strLine,sizeof(strLine));
		ReplaceString(strLine,sizeof(strLine),"\n","");
		if(StrEqual(strNext,strLine)){
			//次のやつを
			do{
				if(IsEndOfFile(hFile)){		//ファイル末尾を考慮すること
					//開き直す				
					CloseHandle(hFile);
					hFile = OpenFile(strCfg,"r");
				}
				strLine = "";
				ReadFileLine(hFile,strLine,sizeof(strLine));
				ReplaceString(strLine,sizeof(strLine),"\n","");
			}while(StrEqual(strLine,"")); //空白だと問題があるので再度読み込む
			
			//NEXTMAPに差し替える
			SetNextMap(strLine);
			break;
		}
	}
	
	CloseHandle(hFile);
	//次のマップもNGになっていないか確認
	//…マップサイクル内のマップが全てNG登録されていた場合、永久ループになる
	Cmd_CheckMap();
}