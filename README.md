# Interlacing-Compositor-Effect
  This is a compositor effect for the Godot Engine. It features an interlacing effect that you would see on older tv's. You can use it by adding it to a Compositor either on your camera or on your WorldEnvironment Node.

  Because this is a Compositor Effect it will only work in the Forward+ and Mobile renderers.

https://github.com/user-attachments/assets/051f7489-9fcf-4103-a844-88e446c6e69d

## Known "issues":
  Due to how this effect works this effect doesn't work well with high refresh rates. The effect uses the previous frame to create the interlacing, meaning high refresh rates makes it super hard to see. 

  I recommend setting your max fps to 60 or less. I will be looking into a version where you can control how often the interlacing updates to compensate to higher refresh rates. 
