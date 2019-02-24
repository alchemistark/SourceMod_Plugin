/*


注意！　このプラグインは恐らく動作しません。


*/

#include <sourcemod>
#include <tf2_stocks>
#include <tf2>

//cvars
new Handle:v_enable = INVALID_HANDLE;		//有効無効
new Handle:v_change = INVALID_HANDLE;		//動作する人数差
new Handle:v_changeall = INVALID_HANDLE;	//チーム変更要請の動作パターン
new Handle:v_changetime = INVALID_HANDLE;	//メニュー操作を待つ時間
new Handle:v_join = INVALID_HANDLE;			//プレイヤーのチーム変更の可否
new Handle:v_death = INVALID_HANDLE;		//死亡時の要請の有効無効
new Handle:v_autochange = INVALID_HANDLE;	//チーム変更強制執行

//menu
new Handle:m_menu = INVALID_HANDLE;

new g_rank[MAXPLAYERS+1];	//スコアランキング

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
	v_change = CreateConVar("sm_tb_change", "2", "動作開始する人数差 (2以上必要）");
	v_changeall = CreateConVar("sm_tb_changeall", "0", "0:スコアトップから順に要請する 1:全員にチーム変更を要請する");
	v_changetime = CreateConVar("sm_tb_changetime", "20", "メニュー操作を待つ時間 0:時間切れなし");
	v_join = CreateConVar("sm_tb_nojoin", "0", "0:チーム変更可 1:チーム変更不可(観戦も不可）");
	v_death = CreateConVar("sm_tb_death", "0", "死亡時に人数差があれば、死んだプレイヤーにチーム変更を要請する(強制執行はOFFになります）　0:無効 1:有効");
	v_autochange = CreateConVar("sm_tb_autochange", "1", "チーム移動してくれるプレイヤーが居なかった場合強制的にチーム移動されるプレイヤー　0:無効 1:スコアトップ 2:ランダム");
	
	//hook
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_death", OnPlayerDeath);
	//cvar変更監視
	HookConVarChange(v_change, OnConVarChanged_change);
	HookConVarChange(v_enable, OnConVarChanged_enable);
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

//ConVar変更時（有効無効切替時）
public OnConVarChanged_enable(ConVar convar, const char[] oldValue, const char[] newValue){

	//有効化時　初期化処理
	new i;
	for(i=0;i<=MaxClients;i++){
		g_rank[i] = 0;
	}
	
}


//CommandListener "jointeam"
public Action:OnPlayerTeamChanged_Listen(client, const String:command[], argc){

	//有利join防止の為、チーム変更不可（観戦に入ることもできない）
	if(GetConVarInt(v_enable) == 1 && IsClientInGame(client) == true && GetConVarInt(v_join) == 1 && GetClientTeam(client) > 1){
		return Plugin_Handled;
	}
}

//EventHook 死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//プラグイン動作状態確認
	//チェックが死亡時点になっている場合のみ動作
	if(GetConVarInt(v_enable) == 0 || GetConVarInt(v_death) == 0){
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//チーム人数に差がある場合のみ実行
	if(IsFakeClient(client) == false && GetClientTeam(client) == Cmd_Check(0,0,false)){	//チェックのみ
		//Flag2 指定クライアントに表示する
		Cmd_OpenMenu(client,2);
	}	
}

//EventHook チーム変更監視
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){

	/*	0:disconnect	1:spec	2:red	3:blu	*/

	//プラグイン動作状態確認
	//チェックが死亡時点になっていない場合のみ動作
	if(GetConVarInt(v_enable) == 0 || GetConVarInt(v_death) == 1){
		return false;
	}
	
	//botの場合実行しない
	if(IsFakeClient(GetClientOfUserId(GetEventInt(event, "userid")))){
		return false;
	}

	//チーム変更による人数変更をチェック
	new iTeam = Cmd_Check(GetEventInt(event, "team"),GetEventInt(event, "oldteam"),false);
	
	//人数差がある場合のみ実行
	if(iTeam > 1){
		Cmd_Change(iTeam);
	}
}

//チーム変更要請を行うかどうかのチェック関数
//プレイヤーの多いチームを返す
//OldTeamは観戦者及び新規joinの可能性がある
public int Cmd_Check(int iNewTeam, int iOldTeam, bool bJoin){

	//iNewTeam 移動により人数が増加するチーム
	//iOldTeam 移動により人数が減少するチーム
	//bJoin		Join時だけは細かい人数をチェックする

	new iBlu = 0;	//Blu人数
	new iRed = 0;	//Red人数
	new iABS;		//人数差
	new iTeam = 0;	//対象チーム
	
	new i;	//forループ用
	
	//各チームの人数をカウントする
	//この時点では実際にチーム移動は行われていない
	for(i=1;i <= MaxClients;i++){
		if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Blue && IsFakeClient(i) == false){
			iBlu++; 	//Blu
		}
		else if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Red && IsFakeClient(i) == false){
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
		if(!bJoin){
			return 0;
		}
	}

	return iTeam;
}

//チーム変更処理
public Cmd_Change(int iTeam){
	
	//指定チームのスコアランキングを作成する(必要な場合)
	if(GetConVarInt(v_changeall) == 0){
		//ランキングを初期化
		new i;
		for(i=1;i<MaxClients;i++){
			g_rank[i] = 0;
		}
		//ランキングを作成
		Cmd_ScoreRank(iTeam);
		//Flag0 指定順位のプレイヤーに要請する
		Cmd_OpenMenu(1,0);
	}
	
	if(GetConVarInt(v_changeall) == 1){
		//Flag1 全員にチーム変更を要請する
		Cmd_OpenMenu(iTeam,1);
	}
}

//指定チームに対して変更要請を行う
public Cmd_OpenMenu(int iValue, int iFlag){
	
	// |iValue|iFlag|
	// | rank |  0  |   指定順位のプレイヤーに変更要請を行う
	// | team |  1  |   指定チーム全員に変更要請を行う
	// |client|  2  |   指定クライアントに変更要請を行う
	
	new i;
	
	//指定順位のプレイヤーに要請する
	if(iFlag == 0){
		//表示時間に0が入った場合、MENU_TIME_FOREVERと同値となる
		DisplayMenu(m_menu, g_rank[iValue], GetConVarInt(v_changetime));
	}
	//全員にチーム変更を要請する
	else if(iFlag == 1){
		for(i=1; i <= MaxClients; i++){
			//対象チームにメニューを表示する
			if(IsClientInGame(i) == true && GetClientTeam(i) == iValue && IsFakeClient(i) == false){
				//メニューを開いたプレイヤーを記録
				g_rank[i] = 1;
				DisplayMenu(m_menu, i, GetConVarInt(v_changetime));
			}
		}
	}
	//死亡時にチーム変更を要請する
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
					
					new i;
					//移動が完了したならば消去するべき
					for(i=1;i<MaxClients;i++){
						g_rank[i] = 0;
					}
					
				}
				//移動を拒否
				else{
					g_rank[param1] = 0;
					Cmd_ReSend();
				}
			}
			//タイムアウトがある
			case MenuAction_Cancel:{
			
				switch(param2){
					case MenuCancel_Timeout:{
						g_rank[param1] = 0;
						Cmd_ReSend();
					}
				}
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}

//移動が拒否された場合
public Cmd_ReSend(){

	new i;
	for(i=1;i<=MaxClients;i++){
		//この順位が存在するか上位から順に確認する
		//もしくは、メニューを開いているプレイヤーが残っているか確認する
		if(g_rank[i] != 0){
			if(GetConVarInt(v_changeall) == 0){
				//存在したら表示
				Cmd_OpenMenu(i,0);
			}
			break;
		}
	}
	
	//全員拒否したので強制執行する
	if(GetConVarInt(v_autochange) != 0 && GetConVarInt(v_death) == 0){
		new iTeam = Cmd_Check(0,0,false);
		new client;
		
		//メニューを出している間に移動が不要になっていたらなにもしない
		if(iTeam != 0){
			//対象を確認する為再度ランキングを作成する
			Cmd_ScoreRank(iTeam);
			if(GetConVarInt(v_autochange) == 1){
				client = g_rank[1];
			}
			else{
				for(i=1;i<=MaxClients;i++){
					if(g_rank[i] == 0){
						break;
					}
				}
				client = (GetURandomInt() % (i-1) + 1);
			}
			
			if(iTeam == TFTeam_Blue){
				iTeam = TFTeam_Red;
			}
			else{
				iTeam = TFTeam_Blue;
			}
			
			TF2_ChangeClientTeam(client,iTeam);
			TF2_RespawnPlayer(client);
			
			//使い終わったら消去
			for(i=1;i<=MaxClients;i++){
				g_rank[i] = 0;
			}
		}
	}	
}
