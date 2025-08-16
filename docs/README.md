## kr0mWidgets:

Custom awesomeWM widgets by kr0m([AlfaExploit](https://alfaexploit.com)).

## Dependencies:
```bash
apt install upower power-profiles-daemon
```

### Features:

CPU,RAM,Battery widgets provides icon and text information.
|           CPU          |         RAM            |
|:----------------------:|:----------------------:|
| ![CPU](images/cpu.png) | ![RAM](images/ram.png) |

Battery widget is a little special, as information is coded in the icon color schema:
- Battery indicator green: Power-saver profile applied.
- Battery indicator mustard: Balanced profile applied.
- Battery indicator red: Performance profile applied.

Lighting symbol indicates AC is pluged-in, blinking warning icon indicates battery is <= 5%.

| Energy |                 Power-saver                |                Balanced                |                  Performance                 |
|:------:|:------------------------------------------:|:--------------------------------------:|:--------------------------------------------:|
|Battery | ![Powersaver](images/powersaver.png)       | ![Balanced](images/balanced.png)       | ![Performance](images/performance.png)       |
|   AC   | ![Powersaver-ac](images/powersaver-ac.png) | ![Balanced-ac](images/balanced-ac.png) | ![Performance-ac](images/performance-ac.png) |

Critical battery threshhold:
![critical-battery](images/critical-battery.png)

### Installation:

```bash
cd ~/.config/awesome
git clone https://github.com/ARPABoy/kr0mWidgets.git
```

### Use:

```bash
vi ~/.config/awesome/rc.lua
```
```lua
require("kr0mWidgets.batteryPercentage")
require("kr0mWidgets.cpuUsage")
require("kr0mWidgets.ramUsage")


Use widgets wherever you desire:
        { -- Right widgets
            kr0mBatteryIcon,
            kr0mBatteryData,
            kr0mCpuIcon,
            kr0mCpuData,
            kr0mRamIcon,
            kr0mRamData,
        },
```
