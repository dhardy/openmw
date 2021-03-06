/*
  OpenMW - The completely unofficial reimplementation of Morrowind
  Copyright (C) 2008  Nicolay Korslund
  Email: < korslund@gmail.com >
  WWW: http://openmw.snaptoad.com/

  This file (config.d) is part of the OpenMW package.

  OpenMW is distributed as free software: you can redistribute it
  and/or modify it under the terms of the GNU General Public License
  version 3, as published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  version 3 along with this program. If not, see
  http://www.gnu.org/licenses/ .

 */

module core.config;

import std.string;
import std.file;
import std.path;
import std.stdio;

import monster.monster;
import monster.util.string;

import core.inifile;
import core.filefinder;

import sound.audio;

import input.keys;
import input.ois;

import ogre.ogre;

ConfigManager config;

/*
 * Structure that handles all user adjustable configuration options,
 * including things like file paths, plugins, graphics resolution,
 * game settings, window positions, etc. It is also responsible for
 * reading and writing configuration files, for importing settings
 * from Morrowind.ini and for configuring OGRE. It doesn't currently
 * DO all of this, but it is supposed to in the future.
 */

struct ConfigManager
{
  MonsterObject *mo;

  IniWriter iniWriter;

  // Mouse sensitivity
  float *mouseSensX;
  float *mouseSensY;
  bool *flipMouseY;

  // Ogre configuration
  bool showOgreConfig; // The configuration setting
  // The actual result, overridable by a command line switch, and also
  // set to true if firstRun is true.
  bool finalOgreConfig;

  // Other settings
  bool firstRun;

  // Set to true if sound is completely disabled
  bool noSound = false;

  // Number of current screen shot. Saved upon exit, so that shots
  // from separate sessions don't overwrite each other.
  int screenShotNum;

  // Game files to load (max 255)
  char[][] gameFiles;

  // Directories
  char[] dataDir;
  char[] esmDir;
  char[] bsaDir;
  char[] sndDir;
  char[] fontDir;
  char[] musDir; // Explore music
  char[] musDir2; // Battle music

  // Configuration file
  char[] confFile = "openmw.ini";

  // Cell to load at startup
  char[] defaultCell;

  // These set the volume to a new value and updates all sounds to
  // take notice.
  void setMusicVolume(float vol)
  {
    stack.pushFloat(vol);
    mo.call("setMusicVolume");
  }
  float getMusicVolume()
  { return mo.getFloat("musicVolume"); }

  void setSfxVolume(float vol)
  {
    stack.pushFloat(vol);
    mo.call("setSfxVolume");
  }
  float getSfxVolume()
  { return mo.getFloat("sfxVolume"); }

  void setMainVolume(float vol)
  {
    stack.pushFloat(vol);
    mo.call("setMainVolume");
  }
  float getMainVolume()
  { return mo.getFloat("mainVolume"); }

  // Initialize the config manager. Send a 'true' parameter to reset
  // all keybindings to the default. A lot of this stuff will be moved
  // to script code at some point. In general, all input mechanics and
  // distribution of key events should happen in native code, while
  // all setup and control should be handled in script code.
  void initialize(bool reset = false)
  {
    // Initialize variables from Monster.
    assert(mo !is null);
    mouseSensX = mo.getFloatPtr("mouseSensX");
    mouseSensY = mo.getFloatPtr("mouseSensY");
    flipMouseY = mo.getBoolPtr("flipMouseY");

    // Initialize the key binding manager
    keyBindings.initKeys();

    /* Disable this at the moment. It's a good idea to put
       configuration in a central location, but it's useless as long
       as Ogre expects to find it's files in the current working
       directory. The best permanent solution would be to let the
       locations of ogre.cfg and plugins.cfg be determined by
       openmw.ini - I will fix that later.

    version(Posix)
      {
        if(!exists(confFile))
          confFile = expandTilde("~/.openmw/openmw.ini");
      }
    */

    readIni(reset);
  }

  // Read config from morro.ini, if it exists. The reset parameter is
  // set to true if we should use default key bindings instead of the
  // ones from the config file.
  void readIni(bool reset)
  {
    // Read configuration file, if it exists.
    IniReader ini;

    ini.readFile(confFile);

    screenShotNum = ini.getInt("General", "Screenshots", 0);
    float mainVolume = saneVol(ini.getFloat("Sound", "Main Volume", 0.7));
    float musicVolume = saneVol(ini.getFloat("Sound", "Music Volume", 0.5));
    float sfxVolume = saneVol(ini.getFloat("Sound", "SFX Volume", 0.5));
    bool useMusic = ini.getBool("Sound", "Enable Music", true);


    lightConst = ini.getInt("LightAttenuation", "UseConstant", 0);
    lightConstValue = ini.getFloat("LightAttenuation", "ConstantValue", 0.0);

    lightLinear = ini.getInt("LightAttenuation", "UseLinear", 1);
    lightLinearMethod = ini.getInt("LightAttenuation", "LinearMethod", 1);
    lightLinearValue = ini.getFloat("LightAttenuation", "LinearValue", 3.0);
    lightLinearRadiusMult = ini.getFloat("LightAttenuation", "LinearRadiusMult", 1.0);

    lightQuadratic = ini.getInt("LightAttenuation", "UseQuadratic", 0);
    lightQuadraticMethod = ini.getInt("LightAttenuation", "QuadraticMethod", 2);
    lightQuadraticValue = ini.getFloat("LightAttenuation", "QuadraticValue", 16.0);
    lightQuadraticRadiusMult = ini.getFloat("LightAttenuation", "QuadraticRadiusMult", 1.0);

    lightOutQuadInLin = ini.getInt("LightAttenuation", "OutQuadInLin", 0);


    *mouseSensX = ini.getFloat("Controls", "Mouse Sensitivity X", 0.2);
    *mouseSensY = ini.getFloat("Controls", "Mouse Sensitivity Y", 0.2);
    *flipMouseY = ini.getBool("Controls", "Flip Mouse Y Axis", false);

    mo.setFloat("mainVolume", mainVolume);
    mo.setFloat("musicVolume", musicVolume);
    mo.setFloat("sfxVolume", sfxVolume);
    mo.setBool("useMusic", useMusic);

    defaultCell = ini.getString("General", "Default Cell", "Assu");

    firstRun = ini.getBool("General", "First Run", true);
    showOgreConfig = ini.getBool("General", "Show Ogre Config", false);

    // This flag determines whether we will actually show the Ogre
    // config dialogue. The EITHER of the following are true, the
    // config box will be shown:
    // - The program is being run for the first time
    // - The "Show Ogre Config" option in openmw.ini is set.
    // - The -oc option is specified on the command line
    // - The file ogre.cfg is missing

    finalOgreConfig = showOgreConfig || firstRun ||
                      !exists("ogre.cfg");

    // Set default key bindings first.
    with(keyBindings)
      {
	// Bind some default keys
	bind(Keys.MoveLeft, KC.A, KC.LEFT);
	bind(Keys.MoveRight, KC.D, KC.RIGHT);
	bind(Keys.MoveForward, KC.W, KC.UP);
	bind(Keys.MoveBackward, KC.S, KC.DOWN);
	bind(Keys.MoveUp, KC.LSHIFT);
	bind(Keys.MoveDown, KC.LCONTROL);

	bind(Keys.MainVolUp, KC.ADD);
	bind(Keys.MainVolDown, KC.SUBTRACT);
	bind(Keys.MusVolDown, KC.N1);
	bind(Keys.MusVolUp, KC.N2);
	bind(Keys.SfxVolDown, KC.N3);
	bind(Keys.SfxVolUp, KC.N4);
        bind(Keys.Mute, KC.M);

        bind(Keys.Fullscreen, KC.F);

	bind(Keys.ToggleBattleMusic, KC.SPACE);
        bind(Keys.PhysMode, KC.T);
        bind(Keys.Nighteye, KC.N);
        bind(Keys.ToggleGui, KC.Mouse1);
        bind(Keys.Console, KC.F1, KC.GRAVE);
        bind(Keys.Debug, KC.G);

	bind(Keys.Pause, KC.PAUSE, KC.P);
	bind(Keys.ScreenShot, KC.SYSRQ);
	bind(Keys.Exit, KC.Q, KC.ESCAPE);
      }

    // Unless the ini file was missing or we were asked to reset all
    // keybindings to default, replace all present bindings with the
    // values from the ini.
    if(!reset && ini.wasRead)
      {
        // Read key bindings
        for(int i; i<Keys.Length; i++)
          {
            char[] s = keyToString[i];
            if(s.length)
              {
                char[] iniVal = ini.getString("Bindings", s, "_def");

                // Was the setting present in the ini file?
                if(iniVal != "_def")
                  // If so, bind it!
                  keyBindings.bindComma(cast(Keys)i, iniVal);
              }
          }
      }

    // Read data file directory
    dataDir = ini.getString("General", "Data Directory", "data/");

    // Make sure there's a trailing slash at the end. The forward slash
    // / works on all platforms, while the backslash \ does not. This
    // isn't super robust, but we will fix a general path handle
    // mechanism later (or use an existing one.)
    if(dataDir.ends("\\")) dataDir[$-1] = '/';
    if(!dataDir.ends("/")) dataDir ~= '/';

    bsaDir = dataDir;
    esmDir = dataDir;
    sndDir = dataDir ~ "Sound/";
    fontDir = dataDir ~ "Fonts/";
    musDir = dataDir ~ "Music/Explore/";
    musDir2 = dataDir ~ "Music/Battle/";

    // A maximum of 255 game files are allowed. Search the whole range
    // in case some holes developed in the number sequence. This isn't
    // a great way of specifying files (it's just a copy of the flawed
    // model that Morrowind uses), but it will do for the time being.
    FileFinder srch = new FileFinder(esmDir, null, Recurse.No);
    for(int i = 0;i < 255;i++)
      {
        char[] s = ini.getString("Game Files", format("GameFile[%d]",i), null);
        if(s != null && srch.has(s))
          gameFiles ~= esmDir ~ s;
      }
    delete srch;

    if(gameFiles.length == 0)
      {
        // No game files set. Look in the esmDir for Morrowind.esm.
        // We can add Tribunal.esm, and Bloodmoon.esm as defaults too
        // later, when we're out of testing mode.
        char[][] baseFiles = ["Morrowind.esm"];
        //char[][] baseFiles = ["Morrowind.esm","Tribunal.esm","Bloodmoon.esm"];
        srch = new FileFinder(esmDir, "esm", Recurse.No);

        foreach(ref s; baseFiles)
          {
            if(srch.has(s))
              {
                writefln("Adding game file %s", s);
                gameFiles ~= esmDir ~ s;
              }
          }
        delete srch;
      }

    // FIXME: Must sort gameFiles so that ESMs come first, then ESPs.
    // I don't know if this needs to be done by filename, or by the
    // actual file type..
    // Further sort the two groups by file date (oldest first).

    /* Don't bother reading every directory seperately
    bsaDir = ini.getString("General", "BSA Directory", "data/");
    esmDir = ini.getString("General", "ESM Directory", "data/");
    sndDir = ini.getString("General", "SFX Directory", "data/Sound/");
    musDir = ini.getString("General", "Explore Music Directory", "data/Music/Explore/");
    musDir2 = ini.getString("General", "Battle Music Directory", "data/Music/Battle/");
    */
  }

  // Create the config file
  void writeConfig()
  {
    //writefln("writeConfig(%s)", confFile);
    with(iniWriter)
      {
	openFile(confFile);

	comment("Don't write your own comments in this file, they");
	comment("will disappear when the file is rewritten.");
	section("General");
	writeString("Data Directory", dataDir);
	/*
	writeString("ESM Directory", esmDir);
	writeString("BSA Directory", bsaDir);
	writeString("SFX Directory", sndDir);
	writeString("Explore Music Directory", musDir);
	writeString("Battle Music Directory", musDir2);
	*/
	writeInt("Screenshots", screenShotNum);
	writeString("Default Cell", defaultCell);

        // Save the setting as it appeared in the input. The setting
        // you specify in the ini is persistent, specifying the -oc
        // parameter does not change it.
        writeBool("Show Ogre Config", showOgreConfig);

        // The next run is never the first run.
        writeBool("First Run", false);

	section("Controls");
	writeFloat("Mouse Sensitivity X", *mouseSensX);
	writeFloat("Mouse Sensitivity Y", *mouseSensY);
	writeBool("Flip Mouse Y Axis", *flipMouseY);

	section("Bindings");
	comment("Key bindings. The strings must match exactly.");
	foreach(int i, KeyBind b; keyBindings.bindings)
	  {
	    char[] s = keyToString[i];
	    if(s.length)
	      writeString(s, b.getString());
	  }

	section("Sound");
	writeFloat("Main Volume", mo.getFloat("mainVolume"));
	writeFloat("Music Volume", mo.getFloat("musicVolume"));
	writeFloat("SFX Volume", mo.getFloat("sfxVolume"));
	writeBool("Enable Music", mo.getBool("useMusic"));

	section("LightAttenuation");
    comment("For constant attenuation");
	writeInt("UseConstant", lightConst);
	writeFloat("ConstantValue", lightConstValue);
    comment("For linear attenuation");
	writeInt("UseLinear", lightLinear);
	writeInt("LinearMethod", lightLinearMethod);
	writeFloat("LinearValue", lightLinearValue);
	writeFloat("LinearRadiusMult", lightLinearRadiusMult);
    comment("For quadratic attenuation");
	writeInt("UseQuadratic", lightQuadratic);
	writeInt("QuadraticMethod", lightQuadraticMethod);
	writeFloat("QuadraticValue", lightQuadraticValue);
	writeFloat("QuadraticRadiusMult", lightQuadraticRadiusMult);
    comment("For quadratic in exteriors and linear in interiors");
	writeInt("OutQuadInLin", lightOutQuadInLin);

	section("Game Files");
	foreach(int i, ref s; gameFiles)
	  writeString(format("GameFile[%d]",i), s[esmDir.length..$]);

	close();
      }
  }

  // In the future this will import settings from Morrowind.ini, as
  // far as this is sensible.
  void importIni()
  {
    /*
    IniReader ini;
    ini.readFile("../Morrowind.ini");

    // Example of sensible options to convert:

    tryArchiveFirst = ini.getInt("General", "TryArchiveFirst");
    useAudio = ( ini.getInt("General", "Disable Audio") == 0 );
    footStepVolume = ini.getFloat("General", "PC Footstep Volume");
    subtitles = ini.getInt("General", "Subtitles") == 1;

    The plugin list (all esm and esp files) would be handled a bit
    differently. In our system they might be a per-user (per
    "character") setting, or even per-savegame. It should be safe and
    intuitive to try out a new mod without risking your savegame data
    or original settings. So these would be handled in a separate
    plugin manager.

    In any case, the import should be interactive and user-driven, so
    there is no use in making it before we have a gui of some sort up
    and running.
    */
  }
}
