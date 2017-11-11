#include <sourcemod>

new g_flag[MAXPLAYERS+1];	//無敵モードフラグ

public Plugin:myinfo = 
{
	name = "muteki",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "ダメージ無効プラグイン",
	version = "1.0",
	url = ""
}


//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	RegAdminCmd("sm_muteki", Cmd_muteki, ADMFLAG_KICK, "sm_muteki <name/id> - 指定のプレイヤーを無敵にする");
	//RegAdminCmd("sm_muteki", Cmd_muteki, 0, "sm_muteki <name/id> - 指定のプレイヤーを無敵にする");
	RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//hook
	HookEvent("player_spawn", OnPlayerSpawned);

	PrintToServer("ダメージ無効プラグイン起動");
	
}

//デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	ServerCommand("sm plugins reload muteki");
	ReplyToCommand(client,"プラグインをリロードしました。");
	return false;
}

//sm_muteki実行時
public Action:Cmd_muteki(client, args)
{
	
	//引数がない場合
	if(args == 0)
	{
		ReplyToCommand(client,"!muteki <name/id> - 指定のプレイヤーを無敵にする");
		return false;
	}
	
	//対象の名前を確保
	new String:strTarget[MAX_NAME_LENGTH];
	GetCmdArgString(strTarget, sizeof(strTarget));
	
	//名前からクライアントを探す…
	char target_name[MAX_NAME_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	if((target_count = ProcessTargetString(
		strTarget,				//検索する名前
		0,						//不明　管理者絡み？
		target_list,			//見つかった対象のリスト？ クライアントindexを配列で返してるっぽい…？
		MAXPLAYERS,				//見つかった対象の数の最大値(定員)
		0,						//フィルターフラグ
		target_name,			//見つかった対象の"グループの"名前(ALL PLAYERS 等)
		sizeof(target_name),	//名前バッファのサイズ
		tn_is_ml)) <= 0)
	{
		//対象なし
		PrintToServer("No matching client");
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	//対象あり
	new i;
	bool boolFlag = false;
	
	for(i = 0;i < target_count;i++){
		//対象の中に無敵フラグを持ってない人は居るか？
		if(g_flag[target_list[i]] == 0){
			boolFlag = true;
			break;
		}
	}
	
	//1人でも対象に無敵じゃない人が居る場合、全員を無敵にする
	//全員が無敵なら、全員無敵を解除する
	for(i = 0;i < target_count;i++){
		//無敵処理へ
		muteki(target_list[i],boolFlag);
	}
	
	
	if(target_count == 1)
	{
		if(boolFlag){
			PrintToChatAll("%sを無敵にしました。",strTarget);
		}
		else{
			PrintToChatAll("%sの無敵を解除しました。",strTarget);
		}
	}
	else
	{
		if(boolFlag){
			PrintToChatAll("%sを無敵にしました。",target_name);
		}
		else{
			PrintToChatAll("%sの無敵を解除しました。",target_name);
		}
	}
	
	return true;
	
}

//HookEvent
public OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast){

	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//無敵フラグを持っている場合のみ
	if(g_flag[client] == 1){
		muteki(client,true);
	}

	return false;
}

public muteki(int client, bool boolFlag){

	/*よくわからないが既存コードより
	//m_takedameの値を0～2の間で変更する　最後の1は書き込みバイト数なので1
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);	//God
	SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);	//Buddha
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);	//Mortal
	*/
	
	//クライアント生存確認
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client)){

		if(boolFlag){
			g_flag[client] = 1;
			SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);	//Buddha
		}
		else{
			g_flag[client] = 0;
			SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);	//Mortal
		}
	
	}
}

public OnClientDisconnect(client){
	//プレイヤー切断時、そのプレイヤーの設定を初期化
	g_flag[client] = 0;
}