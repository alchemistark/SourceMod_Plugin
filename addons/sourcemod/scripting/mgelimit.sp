#include <sourcemod>
#include <tf2_stocks>

public Plugin:myinfo = 
{
	name = "MGE Limit",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "MGEの縛りルール",
	version = "1.0",
	url = ""
}

new Handle:v_enable = INVALID_HANDLE;	//プラグインの有効無効
new Handle:v_mode = INVALID_HANDLE;	//ダメージを受けない・トドメをさせない の切替

new g_enable[MAXPLAYERS+1];	//有効状態かどうか

//プラグイン起動時
public OnPluginStart(){

	//cvar
	v_enable = CreateConVar("sm_ml_enable", "0", "0:disable 1:enable");
	v_mode = CreateConVar("sm_ml_mode", "1", "0:ダメージを受けない ANY:トドメをさせない(ヘルスが0になると設定した値までヘルスを回復させる)");
	
	//event
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_changeclass", OnPlayerChangeclass, EventHookMode_Post);
	
}

//マップ開始時
//マップがMGEでなければ無効化する
public OnMapStart(){

	new Handle:v_map;
	new String:strMapName[5];
	v_map = FindConVar("host_map");
	GetConVarString(v_map,strMapName,sizeof(strMapName));
	if(StrEqual(strMapName,"mge_") == true){
		SetConVarInt(v_enable,0);
	}
}

//EventHook チーム変更処理(切断を含む)
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_enable[client] = 0;
}

//EventHook クラス変更監視
public OnPlayerChangeclass(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new newclass = GetEventInt(event, "class");
	new String:strSection[2];
	IntToString(newclass,strSection,sizeof(strSection));
	
	new Handle:m_menu = CreateMenu(Menu_limit);

	if(newclass == TFClass_Spy){
		SetMenuTitle(m_menu, "Enable to only the back stub?");
	}
	else if(newclass == TFClass_Sniper){
		SetMenuTitle(m_menu, "Enable to only the headshot?");
	}
	else if(newclass == TFClass_Engineer){
		SetMenuTitle(m_menu, "Enable destroy building each round?");
	}
	//対象クラス以外は終了させる
	else{
		CloseHandle(m_menu);	//使用していないのでhandleを閉じる
		return Plugin_Continue;
	}
	
	AddMenuItem(m_menu, strSection, "yes", ITEMDRAW_DEFAULT);
	AddMenuItem(m_menu, "0", "no", ITEMDRAW_DEFAULT);
	DisplayMenu(m_menu,client,20);
	
	return Plugin_Continue;
}	

public Menu_limit(Handle:menu, MenuAction:action, param1, param2) {
	switch(action){	//MenuAction チェック
			case MenuAction_Select:{
				//param1:client index param2:item number
				new String:strSection[2];
				GetMenuItem(menu, param2, strSection, sizeof(strSection));
				g_enable[param1] = StringToInt(strSection);
			}
			//メニュー処理が終了した
			case MenuAction_End:{
				CloseHandle(menu);	//終了したらハンドルを閉じておく
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}


//HookEvent 被ダメ時
public OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	new flag = 0;
	new iHealth;
	new OverHeal;
	
	//スパイかつバックスタブである
	if(g_enable[attacker] == TFClass_Spy && GetEventInt(event, "custom") == 2){
		flag = 1;
	}
	//スナイパーかつヘッドショットである
	else if(g_enable[attacker] == TFClass_Sniper && GetEventInt(event, "custom") == 1){
		flag = 1;
	}
	//対象外
	else if(g_enable[attacker] == 0){
		flag = 1;
	}
	
	//どれにも一致しない場合、ダメージはブロックされる。
	//以下ダメージをブロックする処理
	
	if(flag == 0){
		//モードがダメージ禁止
		if(GetConVarInt(v_mode) == 0){
			//現在のヘルス値とダメージ値を足しておく　eventの"health"は0以下にならないので使ってはならない
			//GetClientHealthはマイナスまでカウントされるのでこちらを使う
			iHealth = GetClientHealth(client) + GetEventInt(event, "damageamount");		
		}
		//モードがキル禁止(指定値まで回復)
		else{
			iHealth = GetConVarInt(v_mode);
			OverHeal = RoundToNearest(GetEntProp(client, Prop_Data, "m_iMaxHealth") * 1.5);
			if(iHealth > OverHeal){
				//指定値がオーバーヒールの最大値を超えていた場合、修正する
				iHealth = OverHeal;
			}
		}
		//回復する
		SetEntityHealth(client, iHealth);
	}
	
	return Plugin_Continue;
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	//デッドリンガーは除外する
	if(GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER == TF_DEATHFLAG_DEADRINGER){
		return Plugin_Continue;
	}
	
	//死んだ人
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	//キルした人
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	
	//死んだプレイヤーか殺したプレイヤーが園児で機能を有効にしている
	if(g_enable[client] == TFClass_Engineer){
		FakeClientCommandEx(client,"destroy 0 0");	//ディスペンサーを破壊
		FakeClientCommandEx(client,"destroy 1 0");	//テレポ入口を破壊
		FakeClientCommandEx(client,"destroy 1 1");	//テレポ出口を破壊
		FakeClientCommandEx(client,"destroy 2 0");	//セントリーを破壊
	}
	
	if(g_enable[attacker] == TFClass_Engineer){
		FakeClientCommandEx(attacker,"destroy 0 0");	//ディスペンサーを破壊
		FakeClientCommandEx(attacker,"destroy 1 0");	//テレポ入口を破壊
		FakeClientCommandEx(attacker,"destroy 1 1");	//テレポ出口を破壊
		FakeClientCommandEx(attacker,"destroy 2 0");	//セントリーを破壊
	}
	
	return Plugin_Continue;
}