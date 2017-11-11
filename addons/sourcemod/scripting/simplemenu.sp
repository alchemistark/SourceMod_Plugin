#include <sourcemod>

new String:g_strConfigFile[PLATFORM_MAX_PATH];
new String:g_execString[255] = "";	//say時のコマンド消去用

new Handle:v_menuStr = INVALID_HANDLE;
new Handle:v_enable = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "simple menu",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "登録されたコマンドを実行するメニューを開きます",
	version = "1.0",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	RegAdminCmd("sm_menu", Cmd_menu, 0, "simple menu 登録されたコマンドを実行するメニューを開きます。");
	//RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//cvar
	v_menuStr = CreateConVar("sm_menu_default", "menu.cfg", "デフォルトのメニューファイル名");
	v_enable = CreateConVar("sm_menu_enable", "1", "SimpleMenuの動作状態　1:有効 他:無効");
	
	//path
	//BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/simplemenu/");

	//say関係コマンドを監視
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");
	
}

//ﾁｬｯﾄﾄﾘｶﾞ用
public Action:Command_Say(client, const String:command[], argc){
	//sayコマンドの内容を確保 argcは必ず１（sayコマンドは発言全てを１語として送るようだ）

	//有効時のみ実行
	if(GetConVarInt(v_enable) !=1){
		return false;
	}
	
	new String:strSay[192];
	new String:strTemp[192];
	new String:strSplit[255];
	GetCmdArg(1,strSay, sizeof(strSay));

	//最初のスペースまでを確保(元の文字列は残す）
	//sayコマンドはチャットからとコンソールからで動作が違う　チャットから打ち込んだ場合、全てを""で囲んでしまう
	if(SplitString(strSay," ",strSplit,sizeof(strSplit)) == -1){
		//引数が無い場合は1語のみ
		StrCopy(strSplit,sizeof(strSplit),strSay);
	}
	
	//実行コマンドの非表示のため、引数を全部繋げる
	new i;
	for(i=2;i<=argc;i++){	//1語のみならスルーされるはず
		GetCmdArg(i,strTemp,sizeof(strTemp));
		//strSay完成させる
		Format(strSay,sizeof(strSay),"%s %s",strSay,strTemp);
	}
	//メニュー呼び出しの場合画面に表示しない(cfgファイル名を指定していることがあるため)
	//チャットトリガを含むコマンドを実行した場合も表示しない
	if(StrEqual(strSplit,"!menu") == true || StrEqual(g_execString,strSay) == true){
		return Plugin_Handled; // blocks command 本来の発言を消す
	}
}


// //デバッグ用 プラグインのリロード
// public Action:Cmd_reload(client, args){
	// ServerCommand("sm plugins reload simplemenu");
	// ReplyToCommand(client,"[SimpleMenu]プラグインをリロードしました。");
	// return false;
// }

//メニューコマンド開始
public Action:Cmd_menu(client, args){

	//有効時のみ実行
	if(GetConVarInt(v_enable) !=1){
		return false;
	}

	new String:strCfg[255];

	//引数がない場合
	if(args == 0)
	{
		GetConVarString(v_menuStr,strCfg,sizeof(strCfg));
	}
	else
	{
		GetCmdArgString(strCfg,sizeof(strCfg));
	}
	
	//実行したクライアントとcfgファイル名を送る
	GenMenuItem(client,strCfg);
	
}

//メニューの作成
public GenMenuItem(int client, String:strCfg[]){
	
	//new String:l_strConfigPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/simplemenu/");
	StrCat(g_strConfigFile,sizeof(g_strConfigFile),strCfg);
	//Format(l_strConfigPath,sizeof(l_strConfigPath),"%s%s",g_strConfigFile,strCfg);

	//ファイルが存在するかどうか
	if (FileExists(g_strConfigFile) == false){
		PrintToChat(client,"[SimpleMenu] ERROR:メニューファイルが無いか、有効なコマンドではありません。");
		return false;
	}

	//ハンドル作成　ルートはSimpleMenu
	new Handle:hKeyValues = CreateKeyValues("SimpleMenu");

	//ファイルを読み込む
	if(FileToKeyValues(hKeyValues,g_strConfigFile) == false) // || KvGotoFirstSubKey(hKeyValues,false) == false)
	{
	//ファイルを開くのに失敗した
		PrintToChat(client,"[SimpleMenu] ERROR:ファイルの読み込みに失敗しました。");
		CloseHandle(hKeyValues);
		return false;
	}
	
	//複数項目、改ページが必要な物はメニュー
	new Handle:menu_SimpleMenu = CreateMenu(SimpleMenu);
	//SetMenuTitle(menu_SimpleMenu, "Simple Menu");

	//タイトルを設定する
	new String:strMenuTitle[255];
	KvGetString(hKeyValues, "menutitle", strMenuTitle, sizeof(strMenuTitle), "Simple Menu");
	SetMenuTitle(menu_SimpleMenu, strMenuTitle);

	if(KvGotoFirstSubKey(hKeyValues,false) == false)
	{
		//ファイルを開くのに失敗した（中身がKeyValueでない、サブキーがない）
		PrintToChat(client,"[SimpleMenu] ERROR:ファイルの記述が間違っているか、文字コードが違います。");
		CloseHandle(hKeyValues);
		return false;
	}
	
	//メニュー作成処理
	new String:strTitle[255];
	new String:strSection[255];
	new String:strAdmin[255];
	new String:strType[255];
	
	new String:strCvarName[255];
	new String:strCvarValue[255];
	//new Handle:hConVar = INVALID_HANDLE;
	
	do
	{
		//メニュー項目を確保
		KvGetString(hKeyValues, "title", strTitle, sizeof(strTitle));
		//KvGetString(hKeyValues, "command", strCmd, sizeof(strCmd));
		KvGetString(hKeyValues, "admin", strAdmin, sizeof(strAdmin));
		KvGetString(hKeyValues, "type", strType, sizeof(strType));
		
		//セクション名を確保
		KvGetSectionName(hKeyValues,strSection,sizeof(strSection));
		
		//タイトルにcvarが含まれているか
		if(strcmp(strType, "onoff",false) == 0){
			SearchCvar(strTitle,sizeof(strTitle),1);
		}
		else{
			SearchCvar(strTitle,sizeof(strTitle),0);
		}
		
		//そのメニューは実行可能か？ titleは設定されているか？（titleは必須項目とする）
		if(CheckCommandAccess(client,strAdmin,0) == true && StrEqual(strTitle,"") == false){
			//Cvarのチェックはあるか？
			if(KvJumpToKey(hKeyValues,"cvar",false) == true){
				KvGetString(hKeyValues, "name", strCvarName, sizeof(strCvarName));
				KvGetString(hKeyValues, "value", strCvarValue, sizeof(strCvarValue));
				//hConVar = FindConVar(strCvarName);
				if(FindConVar(strCvarName) != INVALID_HANDLE){
					GetConVarString(FindConVar(strCvarName),strCvarName,sizeof(strCvarName));	//strCvarnameを再利用するよ
				}
				//ConVarが存在しない場合、実行されるようにする
				else{
					strCvarName = "";
					strCvarValue = "";
				}
				if(StrEqual(strCvarName,strCvarValue)){
					//メニュー項目を作成する
					AddMenuItem(menu_SimpleMenu, strSection, strTitle, ITEMDRAW_DEFAULT);
				}
				//cvarセクションから出る
				KvGoBack(hKeyValues);
			}
			else{
				//メニュー項目を作成する
				AddMenuItem(menu_SimpleMenu, strSection, strTitle, ITEMDRAW_DEFAULT);
			}
		}
		
	}while (KvGotoNextKey(hKeyValues) == true);	//サブキーがある限り実行する
	
	//終了したらハンドルを閉じる
	CloseHandle(hKeyValues);

	//メニューが作成できていない
	if(GetMenuItemCount(menu_SimpleMenu) == 0){
		CloseHandle(menu_SimpleMenu);	//念の為閉じておく
		return false;
	}
	
	//表示処理へ
	DisplayMenu(menu_SimpleMenu,client,MENU_TIME_FOREVER);
	
	return true;
	
}

stock SearchCvar(String:strTarget[], BufferSize, flag){
	
	//flag 0:default 1:onoff 2:cmd
	new intStart = FindCharInString(strTarget,'{');
	new intEnd = FindCharInString(strTarget,'}');
	new String:strCvar[255];
	new String:strTemp[255];
	
	if(intStart == -1 || intEnd == -1 || intEnd - intStart < 0){
		//{もしくは}が見つからなかったもしくは{と}の順序が逆、それかそもそも{}が使用されていない
	}
	else{		
		//strcopyの文字長さは終端文字を含むため1文字増やす必要がある
		//文字列配列に添字を入れると、その文字から残りを表示する
		strcopy(strCvar,intEnd - intStart, strTarget[intStart + 1]);
		
		//cvarの値を確認
		//存在するcvarか？
		if(FindConVar(strCvar) == INVALID_HANDLE){
			PrintToServer("[SimpleMenu] ERROR:Cvarが存在しません %s",strCvar);
			return false;
		}
		GetConVarString(FindConVar(strCvar),strTemp,sizeof(strTemp));
		
		
		//typeがonoffの場合、タイトルに表示されるのは値ではなくonoff表示
		if(flag == 0){
			
		}
		else if(flag == 1){
			if(strcmp(strTemp, "0") == 0){
				strTemp = "On";
			}
			else{
				strTemp = "Off";
			}
		}
		else if(flag == 2){
			if(strcmp(strTemp, "0") == 0){
				Format(strTemp, sizeof(strTemp), "%s 1",strCvar);
			}
			else{
				Format(strTemp, sizeof(strTemp), "%s 0",strCvar);
			}
		}
		
		//表示を書き換える
		Format(strCvar,sizeof(strCvar),"{%s}",strCvar);
		ReplaceString(strTarget,BufferSize,strCvar,strTemp);
		
		//複数Cvarへの対応
		SearchCvar(strTarget, BufferSize, flag);
		
	}
}

//メニュー
public SimpleMenu(Handle:menu, MenuAction:action, param1, param2) {
	
	
	switch(action){	//MenuAction チェック
			//項目選択時
			case MenuAction_Select:{
				//param1:client index param2:item number
				new String:strSection[255];
				
				GetMenuItem(menu, param2, strSection, sizeof(strSection));

				//コマンドの整形と実行を行う関数
				SendCmd(param1,strSection);
				
			}
			//メニュー処理が終了した
			case MenuAction_End:{
				CloseHandle(menu);	//終了したらハンドルを閉じておく
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
	
}

//対象を選択するメニュー
public MenuList(Handle:menu, MenuAction:action, param1, param2) {
	
	
	switch(action){	//MenuAction チェック
			//項目選択時
			case MenuAction_Select:{
				//param1:client index param2:item number
				new String:strCmd[255];
				new String:strFrom[3];
				new iFrom = 0;
				
				GetMenuItem(menu, param2, strCmd, sizeof(strCmd));
				
				//先頭1文字にフラグを付けている
				Format(strFrom,sizeof(strFrom),"%.1s",strCmd);
				//先頭1文字を削る
				Format(strCmd,sizeof(strCmd),"%s",strCmd[1]);
				
				//コマンドの整形と実行を行う関数
				run_cmd(param1,strCmd,strFrom);
				
			}
			//メニュー処理が終了した
			case MenuAction_End:{
				CloseHandle(menu);	//終了したらハンドルを閉じておく
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}

//登録されたコマンドの実行
public SendCmd(int client, String:strSection[]){

	//KeyValueを再度読み込む
	//ハンドル作成　ルートはSimpleMenu
	new Handle:hKeyValues = CreateKeyValues("SimpleMenu");

	//ファイルを読み込む
	//メニューで選択したセクションに移動
	if(FileToKeyValues(hKeyValues,g_strConfigFile) == false || KvJumpToKey(hKeyValues,strSection,false) == false)
	{
	//ファイルを開くのに失敗した（中身がKeyValueでない、サブキーがない）
		PrintToChat(client,"[SimpleMenu] ERROR:ファイルの読み込みに失敗しました。");
		CloseHandle(hKeyValues);
		return false;
	}
	
	new String:strCmd[255];
	new String:strTemp[255];
	new String:strType[10];
	new String:strFrom[10];
	new String:SteamID[30];
	new String:strTarget[255];
	new i = 0;

	KvGetString(hKeyValues, "command", strCmd, sizeof(strCmd));
	KvGetString(hKeyValues, "type", strType, sizeof(strType));
	KvGetString(hKeyValues, "from", strFrom, sizeof(strFrom));

	//念の為不要な空白文字列を消しておく
	TrimString(strCmd);
	while(ReplaceString(strCmd,sizeof(strCmd),"  "," ") != 0){
		//PrintToServer("トリム中… %s",strCmd);
	}
	
	//メニューに送信する項目が足りないので、無理やり挿入する…スマートじゃないねぇ…
	if(StrEqual(strFrom,"client") == true){
		//クライアントから実行
		strFrom = "1";
	}
	else{
		//サーバーから実行
		strFrom = "0";
	}
	//--------------------------------------
	
	
	//メニューは共有する
	new Handle:menu_list = CreateMenu(MenuList);
	//SetMenuTitle(menu_list, "Simple Menu");
	
	if(strcmp(strType,"onoff") == 0){
		
		SearchCvar(strCmd,sizeof(strCmd),2);
		//実行
		run_cmd(client,strCmd,strFrom);
		CloseHandle(menu_list);	//不安だから閉じておく（メニューを開かなかった場合用）
	}
	else if(strcmp(strType,"list") == 0){
		if(KvJumpToKey(hKeyValues,"list",false) == true && KvGotoFirstSubKey(hKeyValues,false) == true){
			do{
				if (KvGetDataType(hKeyValues,NULL_STRING) != KvData_None){
					KvGetSectionName(hKeyValues,strTemp,sizeof(strTemp));	//キー名（実際に実行される値）を取得
					if(StrContains(strCmd,"{target}",false) != -1){
						//{target}との差し替えを準備する
						ReplaceString(strTarget,sizeof(strTarget),"{target}",strTemp);
					}
					else{
						Format(strTarget,sizeof(strTarget),"%s %s",strCmd,strTemp);	//コマンドを整形
					}
					KvGetString(hKeyValues, NULL_STRING, strTemp, sizeof(strTemp));	//キー値(メニューに表示される値)を取得
					
					//実行フラグを先頭に付加する…
					Format(strTarget,sizeof(strTarget),"%s%s",strFrom,strTarget);
					
					AddMenuItem(menu_list, strTarget, strTemp, ITEMDRAW_DEFAULT);
				}
				
			}while(KvGotoNextKey(hKeyValues,false) == true);	//サブキーがある限り実行する

			//メニューが作成できていない
			if(GetMenuItemCount(menu_list) != 0){
				//表示処理へ
				DisplayMenu(menu_list,client,MENU_TIME_FOREVER);
			}
		}
	}
	else if(strcmp(strType,"player") == 0){

		//new String:strTarget[MAX_NAME_LENGTH];
		
		//名前からクライアントを探す…
		char target_name[MAX_NAME_LENGTH];
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;
		
		if((target_count = ProcessTargetString(
			"@humans",				//検索する名前
			0,						//不明　管理者絡み？
			target_list,			//見つかった対象のリスト？ クライアントindexを配列で返してるっぽい…？
			MAXPLAYERS,				//見つかった対象の数の最大値(定員)
			0,						//フィルターフラグ
			target_name,			//見つかった対象の"グループの"名前(ALL PLAYERS 等)
			sizeof(target_name),	//名前バッファのサイズ
			tn_is_ml)) <= 0)
		{
			//対象なし
			//PrintToServer("%s",target_count);
			ReplyToTargetError(client, target_count);
		}
		
		//new i;
		for(i = 0 ;i < target_count ; i++){
			//if(GetClientTeam(target_list[i]) >= 2){
			GetClientName(target_list[i],strTarget,sizeof(strTarget));
			//コマンドとターゲット名を送る
			GetClientAuthId(target_list[i],AuthId_Steam2,SteamID,sizeof(SteamID),true);
			Format(SteamID,sizeof(SteamID),"\"#%s\"",SteamID);	//整形
			if(StrContains(strCmd,"{target}",false) != -1){
				//{target}との差し替えを準備する
				ReplaceString(strTemp,sizeof(strCmd),"{target}",SteamID);
			}
			else{
				Format(strTemp,sizeof(strTemp),"%s %s",strCmd,SteamID);
			}
			
			//実行フラグを先頭に付加する…
			Format(strTemp,sizeof(strTemp),"%s%s",strFrom,strTemp);
			
			//AddMenuItem(メニューハンドル,識別文字列（コールバックなどで使用）,表示文字列,表示種類)
			AddMenuItem(menu_list, strTemp, strTarget, ITEMDRAW_DEFAULT);
			//}
		}

		//メニューが作成できていない
		if(GetMenuItemCount(menu_list) != 0){
			//表示処理へ
			DisplayMenu(menu_list,client,MENU_TIME_FOREVER);
		}
	}
	else if(strcmp(strType,"client") == 0){
		//自分を追加
		GetClientAuthId(client,AuthId_Steam2,SteamID,sizeof(SteamID),true);
		Format(SteamID,sizeof(SteamID),"\"#%s\"",SteamID);	//整形
		if(StrContains(strCmd,"{target}",false) != -1){
			//{target}との差し替えを準備する
			ReplaceString(strCmd,sizeof(strCmd),"{target}",SteamID);
		}
		else{
			Format(strCmd,sizeof(strCmd),"%s %s",strCmd,SteamID);
		}
		//実行
		run_cmd(client,strCmd,strFrom);
		CloseHandle(menu_list);
	}
	else if(strcmp(strType,"map") == 0){
		
		//strTemp : maplist
		new Handle:hMapArray = CreateArray(MAX_NAME_LENGTH);
		
		KvGetString(hKeyValues, "maplist", strTemp, sizeof(strTemp));	//マップリストを取得
		
		if(ReadMapList(hMapArray, _, strTemp, MAPLIST_FLAG_CLEARARRAY | MAPLIST_FLAG_NO_DEFAULT) == INVALID_HANDLE){
			//マップが無い、マップリストが存在しない
			PrintToChat(client,"[SimpleMenu] ERROR:Failed to load maplist.");
		}
		
		for(i = 0 ;i < GetArraySize(hMapArray) ; i++){
			GetArrayString(hMapArray,i,strTemp,sizeof(strTemp));
			if(StrContains(strCmd,"{target}",false) != -1){
				//{target}との差し替えを準備する
				ReplaceString(strTarget,sizeof(strTarget),"{target}",strTemp);
			}
			else{
				Format(strTarget,sizeof(strTarget),"%s %s",strCmd,strTemp);
			}

			//実行フラグを先頭に付加する…
			Format(strTarget,sizeof(strTarget),"%s%s",strFrom,strTarget);
			
			//AddMenuItem(メニューハンドル,識別文字列（コールバックなどで使用）,表示文字列,表示種類)
			AddMenuItem(menu_list, strTarget, strTemp, ITEMDRAW_DEFAULT);
		}
		//メニューが作成できていない
		if(GetMenuItemCount(menu_list) != 0){
			//表示処理へ
			DisplayMenu(menu_list,client,MENU_TIME_FOREVER);
		}
	}
	else{
		//実行
		run_cmd(client,strCmd,strFrom);
		CloseHandle(menu_list);
	}
	
	//終了したらハンドルを閉じる
	CloseHandle(hKeyValues);

}

public run_cmd(int client, String:strCmd[],String:strFrom[]){
	
	//イレギュラー対応
	//sayコマンドかつチャットトリガー使用の場合
	new String:Arg[20][100];
	new String:strTemp[100];
	
	new Handle:Array = CreateArray(100,0);	//まず空の配列を作る
	
	//加工の為確保する
	StrCopy(strTemp,sizeof(strTemp),strCmd);
	//";"で複数コマンドが連結されているかもしれない。コマンド確認の為" "に置き換えておく
	ReplaceString(strTemp, sizeof(strTemp), ";", " ");
	
	new Args = ExplodeString(strTemp," ",Arg,20,100);	//コマンド文字列を分解し、引数の数を確保
	new i;
	for(i=0;i<Args;i++){
		//チャットトリガーかどうかの確認のため先頭1文字を確保
		StrCopy(strTemp,2,Arg[i]);	//終端文字の分1文字増える…
		if(StrEqual(strTemp,"!") == true || StrEqual(strTemp,"/") == true){
			//"!"か"/"が無くても実行できるか？
			//Format(strTemp,sizeof(strTemp),"%s",Arg[i][1]);
			if(CommandExists(Arg[i][1]) == false){
				//実行できないならsm_を先頭に付加して再度確認
				Format(strTemp,sizeof(strTemp),"sm_%s",Arg[i][1]);
				if(CommandExists(strTemp) == true){
					//コマンド権限解除用の配列に追加する
					//ResizeArray(Array,GetArraySize(Array)++);
					PushArrayString(Array,strTemp);
				}
			}
			else{
				//コマンド権限解除用の配列に追加する
				PushArrayString(Array,Arg[i][1]);
			}
		}
		//普通のコマンドか？実行は可能か？
		else if(CommandExists(Arg[i]) == true){
			//コマンド権限解除用の配列に追加する
			PushArrayString(Array,Arg[i]);
		}
		//コマンドとして実行できないものはそのまま流す
	}
	
	//実行できるコマンドか？
	//if(CommandExists(strSplit) == true){
	//実行予定のコマンドが存在するか？（配列は0でないか？）
	if(GetArraySize(Array) > 0){
		//クライアントから実行させる場合
		if(StrEqual(strFrom,"0") == false){
			PrintToServer("[SimpleMenu] Client Executeing \"%s\"",strCmd);
			
			//new i;
			for(i=0;i<GetArraySize(Array);i++){
				GetArrayString(Array,i,strTemp,sizeof(strTemp));
				AddCommandOverride(strTemp, Override_Command, 0);	//コマンド実行権限を消す
			}
			
			//チャットトリガーの場合画面に表示させないようにするため発言内容を確保する
			//SAYとは限らないが、とりあえず最初のコマンドを除いた残りを確保しておく
			i = FindCharInString(strCmd,' ');
			if(i >= 0){
				StrCopy(g_execString,sizeof(g_execString),strCmd[i+1]);
			}
			else{
				//1コマンドしかないよ
				g_execString = "";
			}
			
			FakeClientCommandEx(client,strCmd);
			//UnsetCommandOverride(strSplit, Override_Command);
			
			//直後に権限を戻そうとすると実行されないのでタイマーで遅延させる
			CreateTimer(0.1, Cmd_EndCommanFlag,Array);
		}
		else{
			//サーバーから実行させる場合
			PrintToServer("[SimpleMenu] Server Executeing \"%s\"",strCmd);
			ServerCommand(strCmd);
		}
	}
	//権限解除用の配列がゼロの場合、cfgと判断する
	else{
		//実行できるコマンドではない場合、それをcfgファイル名として再帰実行
		PrintToServer("[SimpleMenu] Menu Executeing \"%s\"",strCmd);
		GenMenuItem(client,strCmd);
	}
	
}

//コマンド実行権限を元に戻す
public Action:Cmd_EndCommanFlag(Handle:timer, Handle:command){
	new String:strCmd[255];
	new i;
	for(i=0;i<GetArraySize(command);i++){
		GetArrayString(command,i,strCmd,sizeof(strCmd));
		UnsetCommandOverride(strCmd, Override_Command);
	}
	//実行が終わったら確保したコマンドを消去しておく
	g_execString = "";
	CloseHandle(command);
}