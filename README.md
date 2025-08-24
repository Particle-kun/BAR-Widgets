# BAR-Widgets

Camera Rotation Reset:

Sets spring camera orientation by chat command or keybind

I made this because anchorkeys aren't persistent and I didn't like that. <br>
I couldn't find a solution to easily and repeatably adjust the camera how I wanted, so I made this widget to address that.


Chat: /camset X Y  (replace XY with the desired values, in degrees)

List of commands: ```/camset X Y         /setcam X Y<br>
                     /camerareset        /resetcamera <br> ```
   
You can also choose to use only 1 value to ONLY update a particular axis like this: /camset 90. <-- that will change your pitch (X) while keeping your yaw (Y) the same.<br>
Alternatively, you can set your yaw and leave pitch unchanged by adding a Y after your singular number like this: /camset 90Y  or  /camset 90y

    
For engine default values, use /camerareset or /resetcamera or alternatively /camset or /setcam without any numbers.

Example keybinds:  ```bind [key] camset 90 0```      You can have as many as you like!
                   ```bind [key] resetcamera```

A value of 0 pitch (X) rotates the camera to be paralell with the ground. A value of 90 will make you look straight down. Default pitch is 63.381* degrees. *See file for technical details<br>
A value of 0 yaw (Y) results in the camera looking "north" / towards the top of the minimap. A value of 180 or -180 will result in looking south / toawrsd the bottom.
