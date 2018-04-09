#include <sourcemod>
#include <tf2_stocks>
#include <tf2>

public Plugin:myinfo =
{
	//プラグイン情報を記述
	name = "[TF2] Waiting time door open",
	author = "AMG",
	description = "Opens all doors at the waiting for players.",
	version = "",
	url = ""
}

//プラグイン開始時にTF2_OnWaitingForPlayersEndが呼ばれてしまうのでフラグを作っておく
new g_flag = 0;

//プラグイン起動時
public OnPluginStart(){
	//諦めた
	HookEvent("player_death", OnPlayerDeath);	//イベントのフックを開始

}

//念のためマップ終了時にもフラグをリセットする
public OnMapEnd(){
	g_flag = 0;
}

/*
	//フラグ変数チェック用
	RegAdminCmd("sm_flag", Cmd_flag, 0, "デバッグコマンド");
	RegAdminCmd("sm_open", Cmd_openstart, 0, "デバッグコマンド");
	RegAdminCmd("sm_close", Cmd_close, 0, "デバッグコマンド");
}

//フラグ変数チェック用
public Action:Cmd_flag(client, args){

	PrintToServer("%d",g_flag);

}
*/


//待機時間開始時に呼び出される（tf2_stocks.inc)
public TF2_OnWaitingForPlayersStart()
{
	PrintToServer("Enable DoorOpen");
	g_flag = 1;	//フラグを立てる
	//通過チェック
	//PrintToServer("WaitTimeStart");
	//HookEvent("player_death", OnPlayerDeath);	//イベントのフックを開始
	
	new ent;
	while ((ent = FindEntityByClassname(ent, "team_round_timer")) != -1)	//名前からエンティティを探す
	{
		CreateTimer(5.0, Cmd_open);	//即実行するとうまくいかないので実行を遅延させるタイマー
		g_flag = 0;	//フラグも折る
		break;
	}
}

//実際にドアを開ける処理
public Action:Cmd_open(Handle:timer){

	new iDoor = -1;
	//大体のドアはfunc_doorエンティティで動いてるので、全てのfunc_doorに対してOpenを送ってドアを開放状態にする
	while ((iDoor = FindEntityByClassname(iDoor, "func_door")) != -1)	//名前からエンティティを探す
	{	//func_doorを見つける度に
		AcceptEntityInput(iDoor, "Open");	//Openを送る
	}
	while ((iDoor = FindEntityByClassname(iDoor, "func_brush")) != -1)	//名前からエンティティを探す
	{	//func_brushを見つける度に
		AcceptEntityInput(iDoor, "Kill");	//ｲﾗｯとしたから死んでもらう
	}
	while ((iDoor = FindEntityByClassname(iDoor, "func_respawnroomvisualizer")) != -1)	//名前からエンティティを探す
	{	//func_respawnroomvisualizerスポーン地点の進入禁止を削除
		PrintToServer("attayo");
		AcceptEntityInput(iDoor, "Kill");	//ｲﾗｯとしたから死んでもらう
	}

}

//待機時間終了時に呼び出される(tf2_stocks.inc)
public TF2_OnWaitingForPlayersEnd()
{
	//やりたい事が終わったので後始末をする
	if(g_flag == 1){
		//通過チェック
		//PrintToServer("WaitTimeEnd");
		//UnhookEvent("player_death", OnPlayerDeath);	//イベントのフックを終了
		g_flag = 0;	//フラグも折る
	}
	
	//待機時間が終了したら、1度ゲームがリセットされるので
	//ドアを閉める処理は不要
	
}

//イベントのフック　死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//通過チェック
	//PrintToServer("OnPlayerDeath");

	//デッドリンガーは除外する
	if(g_flag == 1 && (GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER) != TF_DEATHFLAG_DEADRINGER){
		//4秒でリスポーンするタイマーを開始
		CreateTimer(4.0, Cmd_Respawn,GetClientOfUserId(GetEventInt(event,"userid")));
	}
}

public Action:Cmd_Respawn(Handle:timer, any:client){
	//時間経過後、スポーンする
	//PrintToServer("Spawn Timer");
	if(IsClientInGame(client) == true && g_flag == 1){
		TF2_RespawnPlayer(client);
	}
}