# Interlacing-Compositor-Effect
  This is a compositor effect for the Godot Engine. It features an interlacing effect that you would see on older tv's. You can use it by adding it to a Compositor either on your camera or on your WorldEnvironment Node.

  Because this is a Compositor Effect it will only work in the Forward+ and Mobile renderers.

  There are 2 main versions. The basic InterlaceEffect which just features horizontal interlacing as you'd see. This one has less features but should be a lil bit more performant (and also a bit better looking I think? maybe I'm tweaking). Then there is the AdvancedInterlaceEffect. This one adds features like being able to decide the angle at which things are interlaced, being able to automatically rotate the interlace effect and some other extras! I recommend the basic one for most use cases.

https://github.com/user-attachments/assets/051f7489-9fcf-4103-a844-88e446c6e69d

## Known "issues":
  EDIT: A new value has been added to the shaders that lets you "delay" the updating of the buffer. This means you can manually compensate for higher refresh rates! There is also an automatic solution that will adjust the update frequency based on a target framerate you provide. I recommend 60!

  ~~Due to how this effect works this effect doesn't work well with high refresh rates. The effect uses the previous frame to create the interlacing, meaning high refresh rates makes it super hard to see.~~

  ~~I recommend setting your max fps to 60 or less. I will be looking into a version where you can control how often the interlacing updates to compensate to higher refresh rates.~~ 
