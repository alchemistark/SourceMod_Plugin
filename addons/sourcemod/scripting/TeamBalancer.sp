#include <sourcemod>
#include <tf2_stocks>
#include <tf2>

//cvars
new Handle:v_enable = INVALID_HANDLE;		//有効無効
new Handle:v_change = INVALID_HANDLE;		//動作する人数差
new Handle:v_changeall = INVALID_HANDLE;	//チーム変更要請の動作パターン
new Handle:v_changetime = INVALID_HANDLE;	//メニュー操作を待つ時間
new Handle:v_waittime = INVALID_HANDLE;		//メニュー表示のインターバル
new Handle:v_join = INVALID_HANDLE;			//プレイヤーのチーム変更の可否
new Handle:v_death = INVALID_HANDLE;		//死亡時の要請の有効無効

//menu
new Handle:m_menu = INVALID_HANDLE;

new g_rank[MAXPLAYERS+1];	//スコアランキング
new Float:g_time = 0.0;	//経過時間確認用

public Plugin:myinfo = 
{
	name = "[TF2]TeamBalancer",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "両チーム間の人数差を解消します。",
	version = "",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//cvar
	v_enable = CreateConVar("sm_tb_enable", "0", "[TeamBalancer]プラグインの有効無効 1:有効 0:無効");
	v_change = CreateConVar("sm_tb_change", "2", "動作開始する人数差");
	v_changeall = CreateConVar("sm_tb_changeall", "0", "0:スコアトップから順に要請する 1:全員にチーム変更を要請する");
	v_changetime = CreateConVar("sm_tb_changetime", "20", "メニュー操作を待つ時間 0:時間切れなし");
	v_waittime = CreateConVar("sm_tb_waitetime", "20", "メニュー表示のインターバル 0:インターバルなし");
	v_join = CreateConVar("sm_tb_nojoin", "0", "0:チーム変更可 1:チーム変更不可(観戦も不可）");
	v_death = CreateConVar("sm_tb_death", "0", "死亡時に人数差があれば要請する");
	
	//hook
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_death", OnPlayerDeath);
	//cvar変更監視
	HookConVarChange(v_change, OnConVarChanged_change);
	//CommandListener(有利join禁止用)
	AddCommandListener(OnPlayerTeamChanged_Listen, "jointeam");
	
	m_menu = CreateMenu(Cmd_menu);
	SetMenuTitle(m_menu, "相手チームの人数が少なくなっています。チームを移動しますか？");
	AddMenuItem(m_menu, "1", "移動する", ITEMDRAW_DEFAULT);
	AddMenuItem(m_menu, "0", "移動しない", ITEMDRAW_DEFAULT);
	SetMenuExitButton(m_menu, false);
	
}

//デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	ServerCommand("sm plugins reload TeamBalancer");
	ReplyToCommand(client,"[TeamBalancer]プラグインをリロードしました。");
	return false;
}

public Action:Cmd_score(client, args){
	Cmd_ScoreRank(GetClientTeam(client));
	return false;
}

//ConVar変更時（動作人数を変更した時）
public OnConVarChanged_change(ConVar convar, const char[] oldValue, const char[] newValue){

	//最低2人以上の差が必要
	if(StringToInt(newValue) < 2){
		PrintToServer("[TeamBalancer]ERROR:sm_tb_changeは2以上の値が必要です。");
		new iValue = StringToInt(oldValue);
		SetConVarInt(convar,iValue,false,false);
		return false;
	}
}

//CommandListener "jointeam"
public Action:OnPlayerTeamChanged_Listen(client, const String:command[], argc){
	//有利join防止の為、チーム変更不可（観戦に入ることもできない）
	if(GetConVarInt(v_enable) == 1 && GetConVarInt(v_join) == 1 && IsClientInGame(client) == true && GetClientTeam(client) > 1){
		return Plugin_Handled;
	}
}

//EventHook 死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//プラグイン動作状態確認
	if(GetConVarInt(v_enable) == 0 && GetConVarInt(v_death) == 0){
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(GetClientTeam(client) == Cmd_Change(0,0,true)){
		//Flag2 指定クライアントに表示する
		Cmd_OpenMenu(client,2);
	}	
}

//EventHook チーム変更監視
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){

	/*
	0:disconnect
	1:spec
	2:red
	3:blu
	*/

	//プラグイン動作状態確認
	if(GetConVarInt(v_enable) == 0){
		return false;
	}

	//再呼び出し可能にする		チーム変更時、もしくは死亡時に呼び出し
	Cmd_Change(GetEventInt(event, "team"),GetEventInt(event, "oldteam"), false);
	
}

//チーム変更要請を行うかどうかのチェック関数
public int Cmd_Change(int iNewTeam, int iOldTeam, bool CheckOnly){

	//iNewTeam 移動により人数が増加するチーム
	//iOldTeam 移動により人数が減少するチーム
	//CheckOnly	trueの場合、返り値としてチームを返し、表示処理は行わない
	//再呼び出しの時は0などを指定して人数変動を起きないようにすること

	new iBlu = 0;	//Blu人数
	new iRed = 0;	//Red人数
	new iABS;		//人数差
	new iTeam;		//対象チーム
	
	new i;	//forループ用
	
	//各チームの人数をカウントする
	//この時点では実際にチーム移動は行われていない
	for(i=1;i <= MaxClients;i++){
		if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Blue){
			iBlu++; 	//Blu
		}
		else if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Red){
			iRed++;		//Red
		}
	}

	//Eventによる変動を加味する
	//増加したチーム
	if(iNewTeam == TFTeam_Blue){
		iBlu++;
	}
	else if(iNewTeam == TFTeam_Red){
		iRed++;
	}
	
	//減少したチーム
	if(iOldTeam == TFTeam_Blue){
		iBlu--;
	}
	else if(iOldTeam == TFTeam_Red){
		iRed--;
	}

	//差分を取得する abs関数無いのね…
	if(iBlu >= iRed){
		iABS = iBlu - iRed;
		iTeam = TFTeam_Blue;
	}
	else{
		iABS = iRed - iBlu;
		iTeam = TFTeam_Red;
	}
	
	//設定人数より少ない場合、実行しない(もしくは1名以下が設定されてしまった場合実行しない)
	if(iABS < GetConVarInt(v_change) || iABS < 2){
		return false;
	}
	
	if(CheckOnly){
		//チェックのみの場合、チームを返す
		return iTeam;
	}
	
	new Float:time = GetEngineTime();
	time = time - g_time;
	//指定時間の経過を確認
	
	if(GetConVarInt(v_waittime) > time){
		PrintToServer("[TeamBalancer] Cmd_Change:指定時間が経過していない為処理を中断します。 LEFT:%f",GetConVarInt(v_waittime) - time);
		return false;
	}
	else{
		//時刻を更新
		g_time = GetEngineTime();
	}
	
	
	//指定チームのスコアランキングを作成する(必要な場合)
	if(GetConVarInt(v_changeall) == 0){
		if(Cmd_ScoreRank(iTeam) == false){
			//スコアランキング使用中（メニュー表示中）ならば処理自体を中止する
			PrintToServer("[TeamBalancer] (スコアトップから表示)メニュー表示中です");
			return 0;
		}
	}
	// else{
		//指定チームに対して変更要請を行う トップからの場合、1を渡す
		//Cmd_OpenMenu(iTeam,1);
	// }
	
	if(GetConVarInt(v_changeall) == 1){
		//Flag1 全員にチーム変更を要請する
		Cmd_OpenMenu(iTeam,1);
	}
	else if(GetConVarInt(v_changeall) == 0){
		//Flag0 スコアトップから順に要請する
		Cmd_OpenMenu(1,0);
	}

}

//指定チームに対して変更要請を行う
//public Cmd_OpenMenu(int iTeam, int iRank){
public Cmd_OpenMenu(int iValue, int iFlag){
	//PrintToServer("iTeam:%d iRank:%d Client:%d にメニューを表示します",iTeam,iRank,g_rank[iRank]);
	//iRank メニューを開かせる順位
	
	// |iValue|iFlag|
	// | team |  1  |   指定チーム全員に変更要請を行う
	// | rank |  0  |   スコアトップから順に変更要請を行う
	// |client|  2  |   指定クライアントに変更要請を行う
	
	//new iTemp;		//フラグ管理用
	
	//全員にチーム変更を要請する
	new i;
	//if(GetConVarInt(v_changeall) == 1){	
	
	if(iFlag == 1){
		for(i=1; i <= MaxClients; i++){
			//対象チームにメニューを表示する
			if(IsClientInGame(i) == true && GetClientTeam(i) == iValue && IsFakeClient(i) == false){
				//表示時間に0が入った場合、MENU_TIME_FOREVERと同値となる
				DisplayMenu(m_menu, i, GetConVarInt(v_changetime));
			}
		}
	}
	//スコアトップから順に要請する
	else if(iFlag == 0){
		//iTemp = g_rank[iValue];	//先に確保する
		//g_rank[iValue] = 0;	//表示したクライアントは消去する
		DisplayMenu(m_menu, g_rank[iValue], GetConVarInt(v_changetime));
		//PrintToServer("g_rank[%d]:%d　にメニューを表示させます",iRank,iTemp);
	}
	//死亡時
	else if(iFlag == 2){
		if(IsClientInGame(iValue) == true && IsFakeClient(iValue) == false){
			DisplayMenu(m_menu, iValue, GetConVarInt(v_changetime));
		}
	}
}

//指定チームのスコアランキングを作成する
public bool Cmd_ScoreRank(int iTeam){

	//iTeam 変更要請するチーム
	//g_rank[MAXPLAYERS+1] ランキング
	new i;	//client番号
	new j;	//順位
	new temp1;
	new temp2;	//スコア一時保管
	new flag[MAXPLAYERS+1];	//チェック済みのフラグ
	
	//ランキングが使用中ならメニュー表示中である
	for(i=0;i<=MaxClients;i++){
		// PrintToServer("g_rank[%d] %d",i,g_rank[i]);
		if(g_rank[i] != 0){
			// PrintToServer("g_rank[%d]使用中 %d",i,g_rank[i]); 
			return false;
		}
		//flag[i] = 0;
	}

	for(j=1; j <= MaxClients; j++){	//順位ループ
		for(i=1; i <= MaxClients; i++){	//クライアントループ
			if(IsClientInGame(i) == true && GetClientTeam(i) == iTeam && flag[i] == 0 && IsFakeClient(i) == false){
				//現在順位のスコアを控える
				if(g_rank[j] > 0){
					temp1 = GetEntProp(g_rank[j], Prop_Send, "m_iPoints", 4);	//この順位のスコア
				}
				else{
					//この順位にまだ誰も記録してないので基準スコアをマイナスにしておく
					temp1 = -1;
				}
				//比較対象スコア
				temp2 = GetEntProp(i, Prop_Send, "m_iPoints", 4);			//比較するスコア
				if(temp1 < temp2){	//既に順位に入っているクライアントを除外しておく
					//順位更新
					g_rank[j] = i;
				}
			}
		}
		//順位が決まったクライアントはフラグを建てておく
		flag[g_rank[j]] = 1;
	}
	
	//現時点のランキングを表示（デバッグ用
	// for(i=1;i<=MaxClients;i++){
		// if(g_rank[i] != 0){
			// PrintToServer("g_rank[%d]:%d",i,g_rank[i]);
		// }
	// }
	return true;
	
}

//メニュー
public Cmd_menu(Handle:menu, MenuAction:action, param1, param2) {
	switch(action){	//MenuAction チェック
			case MenuAction_Select:{
				
				new String:strItem[2];
				GetMenuItem(menu, param2, strItem, sizeof(strItem));
				
				//移動を了承
				if(StringToInt(strItem) == 1){
					if(GetClientTeam(param1) == TFTeam_Blue){
						TF2_ChangeClientTeam(param1,TFTeam_Red);
					}
					else{
						TF2_ChangeClientTeam(param1,TFTeam_Blue);
					}
					
					TF2_RespawnPlayer(param1);
					
					//移動が発生したらメニューは削除する
					CancelMenu(menu);
					
					if(GetConVarInt(v_changeall) == 0){
						new i;
						//移動が完了したならば消去するべき
						for(i=1;i<MaxClients;i++){
							g_rank[i] = 0;
						}
					}
				}
				//移動を拒否、トップから順に表示の場合
				else if(GetConVarInt(v_changeall) == 0){
					//PrintToServer("kyohi");
					g_rank[param1] = 0;
					Cmd_ReSend();
				}
				//それ以外はなにもしない
			}
			//タイムアウトがある
			case MenuAction_Cancel:{
			
				switch(param2){
					// case MenuCancel_Interrupted:{
						// PrintToServer("[TeamBalancer]ERROR:MenuCancel_Interrupted");
					// }
					// case MenuCancel_Exit:
						// PrintToServer("MenuCancel_Exit");
					// case MenuCancel_NoDisplay:{
						// //NoDisplayはちょっとマズい?
						// PrintToServer("[TeamBalancer]ERROR:MenuCancel_NoDisplay");
					// }
					case MenuCancel_Timeout:{
						// PrintToServer("MenuCancel_Timeout");
						if(GetConVarInt(v_changeall) == 0){
							g_rank[param1] = 0;
							Cmd_ReSend();
						}
					}
					// case MenuCancel_ExitBack :
						// PrintToServer("MenuCancel_ExitBack ");
				}
			}
			
			//メニュー処理が終了した
			// case MenuAction_End:{
				//PrintToServer("end");
				//CloseHandle(menu);	//終了したらハンドルを閉じておく
			// }
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}

public Cmd_ReSend(){

	new i;
	for(i=1;i<=MaxClients;i++){
		//この順位が存在するか上位から順に確認する
		if(g_rank[i] != 0){
			//存在したら表示
			Cmd_OpenMenu(i,0);
			break;
		}
	}
}
