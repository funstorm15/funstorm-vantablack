// Omarchy-style top bar. `colorizer` (Panel Colorizer settings) is prepended by install.sh.
panels().forEach(function (old) { old.remove(); });

var p = new Panel;
p.location = "top";
p.floating = false;
p.lengthMode = "fill";
p.height = 28;
p.hiding = "none";

var menu = p.addWidget("dev.xarbit.appgrid");             // menu (Meta), opens on favorites
menu.currentConfigGroup = ["General"];
menu.writeConfig("useCustomButtonImage", true);
menu.writeConfig("customButtonImage", "file://@MENU_ICON@");
menu.writeConfig("startWithFavorites", true);
menu.writeConfig("iconShadow", false);
menu.writeConfig("hoverAnimation", 2);
menu.writeConfig("showDividers", false);
menu.writeConfig("iconSize", 1);
p.addWidget("funstorm.workspaces");                       // 1 2 3 4 5
p.addWidget("org.kde.plasma.panelspacer");
var clock = p.addWidget("org.kde.plasma.digitalclock");   // "Wednesday 17:11"
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "dddd");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("use24hFormat", 2);
p.addWidget("org.kde.plasma.panelspacer");
var tasks = p.addWidget("org.kde.plasma.icontasks");      // only minimized windows
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("showOnlyMinimized", true);
tasks.writeConfig("launchers", "");
tasks.writeConfig("iconSpacing", 1);
p.addWidget("org.kde.plasma.systemtray");
var c = p.addWidget("luisbocanegra.panel.colorizer");     // black glass, 50%
c.currentConfigGroup = ["General"];
c.writeConfig("hideWidget", true);
c.writeConfig("globalSettings", JSON.stringify(colorizer));
