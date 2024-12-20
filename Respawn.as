[Setting hidden]
int Max_Respawns = 100;

[Setting hidden]
int Total_Respawns = 0;

[Setting hidden]
int Total_Resets = 0;

[Setting hidden]
int Total_Finishes = 0;

namespace Respawn {

    string prevMapId = "";

    // Note: prevNumRespawns has to be separate from currMapRespawns because the GUIPlayer.NbRespawnsRequested resets after a finish or a reset.
    int prevNumRespawns = 0;
    int currMapRespawns = 0;
    int currMapResets = 0;
    int currMapFinishes = 0;
    bool resetHandled = true;
    bool finishHandled = false;
    bool respawnYellowNotificationShown = false;
    bool respawnRedNotificationShown = false;

    string timeBetweenTotalRespawns = "0";
    string timeBetweenCurrentRespawns = "0";
    string timeBetweenTotalFinishes = "0";
    string timeBetweenCurrentFinishes = "0";
    string timeBetweenTotalResets = "0";
    string timeBetweenCurrentResets = "0";

    void Update() {

        auto app = GetApp();
        RenderDataTable();
        auto map = app.RootMap;
        if (map is null) {
            prevNumRespawns = 0;
            currMapRespawns = 0;
            currMapResets = 0;
            currMapFinishes = 0;
            Timer::currMapTimePlayed = 0;
            SetTimeBetweenCurrentRespawns();
            SetTimeBetweenCurrentResets();
            SetTimeBetweenCurrentFinishes();
            return;
        }
        if (prevMapId != map.IdName) {
            prevMapId = map.IdName;
            currMapRespawns = 0;
            prevNumRespawns = 0;
            SetTimeBetweenCurrentRespawns();
        }
        auto playground = app.CurrentPlayground;
        if (playground is null || playground.GameTerminals.Length <= 0) return;
        auto terminal = playground.GameTerminals[0];
        auto gui_player = cast<CSmPlayer>(terminal.GUIPlayer);
        if (gui_player is null) return;

        // Finishes section
        auto ui_sequence = terminal.UISequence_Current;
        if (!finishHandled && ui_sequence == CGamePlaygroundUIConfig::EUISequence::Finish) {
            finishHandled = true;
            currMapFinishes += 1;
            Total_Finishes += 1;
            SetTimeBetweenTotalFinishes();
            SetTimeBetweenCurrentFinishes();

        }
        if (finishHandled && ui_sequence != CGamePlaygroundUIConfig::EUISequence::Finish)
            finishHandled = false;

        // Resets section
        // Note: This currently includes finishes as a reset, as that's the only way to start a new map. Also, new maps start with 1 reset, which is the first attempt.
        auto post = (cast<CSmScriptPlayer>(gui_player.ScriptAPI)).Post;
        if (post == CSmScriptPlayer::EPost::CarDriver) {
            resetHandled = false;
        }

        if (!resetHandled && post == CSmScriptPlayer::EPost::Char) {
            resetHandled = true;
            currMapResets += 1;
            prevNumRespawns = 0;
            Total_Resets += 1;
            SetTimeBetweenCurrentResets();
            SetTimeBetweenTotalResets();

        }

        // Respawns section
	    int currNumRespawns = gui_player.Score.NbRespawnsRequested;
        if (currNumRespawns > prevNumRespawns && currNumRespawns > 0) {
            prevNumRespawns = currNumRespawns;
            currMapRespawns = currNumRespawns;
            SetTimeBetweenCurrentRespawns();
            Total_Respawns = Total_Respawns + 1;
            SetTimeBetweenTotalRespawns();
        }

        if (Total_Respawns + Total_Resets > (Max_Respawns * 0.9) && !respawnYellowNotificationShown) {
            UI::ShowNotification("Respawn Count Nearly Reached", "Finish Strong!", GlobalProps::Yellow_Warning_Color, 5000);
            respawnYellowNotificationShown = true;
        }

        if (Total_Respawns + Total_Resets > Max_Respawns && !respawnRedNotificationShown) {
            UI::ShowNotification("Respawn Count Passed", "Take a break! Or last run :(", GlobalProps::Red_Warning_Color, 5000);
            respawnRedNotificationShown = true;
        }
    }

    void RenderDataTable() {
        UI::SetNextWindowPos(200, 200, false ? UI::Cond::Always : UI::Cond::FirstUseEver);
        int window_flags = 
        UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking;
        UI::Begin("Respawn Counter", window_flags);
        if (Setting_Show_Session_Start_Time ||
            Setting_Show_Session_Time_Played ||
            Setting_Show_CurrMap_Time_Played ||
            Setting_Show_Time_Left ||
            Setting_Show_Respawns_Left
        ) {
            UI::BeginGroup();

            string gameTimeRemaining = Time::Format(Time_Left_MS, false, true, true);

            Time::Info currTimeInfo = Time::Parse(Time::Stamp);
            string currTime = (currTimeInfo.Hour <= 9 ? "0" + tostring(currTimeInfo.Hour) : tostring(currTimeInfo.Hour)) + ":" + (currTimeInfo.Minute <= 9 ? "0" + tostring(currTimeInfo.Minute) : tostring(currTimeInfo.Minute)) + ":" + (currTimeInfo.Second <= 9 ? "0" + tostring(currTimeInfo.Second) : tostring(currTimeInfo.Second));

            if (Setting_Show_Session_Start_Time) {
                UI::Text("Session Start Time: " + Timer::sessionStartTime + " / " + "Current Time: " + currTime);
            }

            if (Setting_Show_Session_Time_Played) {
                UI::Text("Time Played This Session: " + Time::Format(Timer::totalTimePlayed, false, true, true));
            }

            if (Setting_Show_CurrMap_Time_Played) {
                UI::Text("Time Played Current Map: " + Time::Format(Timer::currMapTimePlayed, false, true, true));
            }
            
            if (Setting_Show_Time_Left) {
                UI::Text("Time Left: ");
                UI::SameLine();
                // Changes the text color of time based on time remaining.
                if (Time_Left_MS < (Max_Time_MS / 10) && Time_Left_MS >= 0) {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Yellow_Warning_Color);
                    UI::Text(gameTimeRemaining);
                    UI::PopStyleColor();
                } else if (Time_Left_MS < 0) {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Red_Warning_Color);
                    UI::Text(gameTimeRemaining);
                    UI::PopStyleColor();
                } else {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Green_Notification_Color);
                    UI::Text(gameTimeRemaining);
                    UI::PopStyleColor();
                }
                UI::SameLine();
                
                UI::Text(" / Max Time: " + Time::Format(Max_Time_MS, false, true,  true));
            }

            if (Setting_Show_Respawns_Left) {
                UI::Text("Respawns this session: ");
                UI::SameLine();
                // Changes the text color of Respawns based on Respawns remaining.
                if ((Total_Resets + Total_Respawns) >= (Max_Respawns * 0.9) && (Total_Resets + Total_Respawns) <= Max_Respawns) {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Yellow_Warning_Color);
                    UI::Text(tostring(Total_Resets + Total_Respawns));
                    UI::PopStyleColor();
                } else if ((Total_Resets + Total_Respawns) > Max_Respawns) {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Red_Warning_Color);
                    UI::Text(tostring(Total_Resets + Total_Respawns));
                    UI::PopStyleColor();
                } else {
                    UI::PushStyleColor(UI::Col::Text, GlobalProps::Green_Notification_Color);
                    UI::Text(tostring(Total_Resets + Total_Respawns));
                    UI::PopStyleColor();
                }
                UI::SameLine();
                
                UI::Text(" / Max Respawns: " + Max_Respawns);
            }

            UI::EndGroup();

        }

        if (Setting_Show_Resets ||
            Setting_Show_Respawns ||
            Setting_Show_Respawns_And_Resets ||
            Setting_Show_Finishes ||
            Setting_Show_Average_Respawns_Per_Attempt ||
            Setting_Show_Average_Respawns_Per_Finish ||
            Setting_Show_Average_Attempts_Per_Finish ||
            Setting_Show_Average_Respawns_And_Attempts_Per_Finish ||
            Setting_Show_Average_Time_Per_Respawn ||
            Setting_Show_Average_Time_Per_Reset ||
            Setting_Show_Average_Time_Per_Finish
        ) {

            UI::BeginGroup();

            UI::BeginTable("table", 3, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("Category");
            UI::TableNextColumn();
            UI::Text("Total");
            UI::TableNextColumn();
            UI::Text("Current Map");

            UI::TableSetBgColor(UI::TableBgTarget::RowBg0, vec4(0,0,0,1));

            if (Setting_Show_Respawns_And_Resets) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Respawns + Resets: ");
                UI::TableNextColumn();
                UI::Text(tostring(Total_Resets + Total_Respawns));
                UI::TableNextColumn();
                UI::Text(tostring(currMapResets + currMapRespawns));
            }

            if (Setting_Show_Respawns) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Respawns: ");
                UI::TableNextColumn();
                UI::Text(tostring(Total_Respawns));
                UI::TableNextColumn();
                UI::Text(tostring(currMapRespawns));
            }

            if (Setting_Show_Resets) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Resets: ");
                UI::TableNextColumn();
                UI::Text(tostring(Total_Resets));
                UI::TableNextColumn();
                UI::Text(tostring(currMapResets));
            }

            if (Setting_Show_Finishes) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Finishes: ");
                UI::TableNextColumn();
                UI::Text(tostring(Total_Finishes));
                UI::TableNextColumn();
                UI::Text(tostring(currMapFinishes));
            }

            if (Setting_Show_Average_Respawns_Per_Attempt) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Respawns / Attempt: ");
                UI::TableNextColumn();
                UI::Text((Total_Resets <= 0) ? "0" : tostring(Math::Round((Total_Respawns / double(Total_Resets)), 2)));
                UI::TableNextColumn();
                UI::Text((currMapResets <= 0) ? "0" : tostring(Math::Round((currMapRespawns / double(currMapResets)), 2)));
            }

            if (Setting_Show_Average_Respawns_Per_Finish) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Respawns / Finish: ");
                UI::TableNextColumn();
                UI::Text((Total_Finishes <= 0) ? "0" : tostring(Math::Round((Total_Respawns / double(Total_Finishes)), 2)));
                UI::TableNextColumn();
                UI::Text((currMapFinishes <= 0) ? "0" : tostring(Math::Round((currMapRespawns / double(currMapFinishes)), 2)));
            }

            if (Setting_Show_Average_Attempts_Per_Finish) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Attempts / Finish: ");
                UI::TableNextColumn();
                UI::Text((Total_Finishes <= 0) ? "0" : tostring(Math::Round((Total_Resets / double(Total_Finishes)), 2)));
                UI::TableNextColumn();
                UI::Text((currMapFinishes <= 0) ? "0" : tostring(Math::Round((currMapResets / double(currMapFinishes)), 2)));
            }

            if (Setting_Show_Average_Respawns_And_Attempts_Per_Finish) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Rsp + Atps / Finish: ");
                UI::TableNextColumn();
                UI::Text((Total_Finishes <= 0) ? "0" : tostring(Math::Round((Total_Respawns + Total_Resets / double(Total_Finishes)), 2)));
                UI::TableNextColumn();
                UI::Text((currMapFinishes <= 0) ? "0" : tostring(Math::Round((currMapRespawns + currMapResets / double(currMapFinishes)), 2)));
            }

            if (Setting_Show_Average_Time_Per_Respawn) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Time / Respawn: ");
                UI::TableNextColumn();
                UI::Text(timeBetweenTotalRespawns);
                UI::TableNextColumn();
                UI::Text(timeBetweenCurrentRespawns);
            }

            if (Setting_Show_Average_Time_Per_Reset) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Time / Attempt: ");
                UI::TableNextColumn();
                UI::Text(timeBetweenTotalResets);
                UI::TableNextColumn();
                UI::Text(timeBetweenCurrentResets);
            }

            if (Setting_Show_Average_Time_Per_Finish) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Avg. Time / Finish: ");
                UI::TableNextColumn();
                UI::Text(timeBetweenTotalFinishes);
                UI::TableNextColumn();
                UI::Text(timeBetweenCurrentFinishes);
            }

            UI::EndTable();
            UI::EndGroup();
        }
        UI::End();
    }

    void SetTimeBetweenCurrentRespawns() {
        timeBetweenCurrentRespawns = currMapRespawns <= 0 ? "0" : Time::Format(Timer::currMapTimePlayed / currMapRespawns, false, true,  true);
    }
    
    void SetTimeBetweenTotalRespawns() {
        timeBetweenTotalRespawns = Total_Respawns <= 0 ? "0" : Time::Format(Timer::totalTimePlayed / Total_Respawns, false, true,  true);
    }
    
    void SetTimeBetweenCurrentResets() {
        timeBetweenCurrentResets = currMapResets <= 0 ? "0" : Time::Format(Timer::currMapTimePlayed / currMapResets, false, true,  true);
    }
    
    void SetTimeBetweenTotalResets() {
        timeBetweenTotalResets = Total_Resets <= 0 ? "0" : Time::Format(Timer::totalTimePlayed / Total_Resets, false, true,  true);
    }
    
    void SetTimeBetweenCurrentFinishes() {
        timeBetweenCurrentFinishes = currMapFinishes <= 0 ? "0" : Time::Format(Timer::currMapTimePlayed / currMapFinishes, false, true,  true);
    }

    void SetTimeBetweenTotalFinishes() {
        timeBetweenTotalFinishes = Total_Finishes <= 0 ? "0" : Time::Format(Timer::totalTimePlayed / Total_Finishes, false, true,  true);
    }

}