# Gods of Fire

In Javascript for an HTML page, i would like a continuous world simulator in 
which test test AI bots.  

The world should have a map generator to start a world 
and a way to plugin code for the programming of the minds of three types of 
animal: wolf, deer, and human.  The animals should each have its plugged in mind 
executed once each passing moment in the world.  It should be able to read its 
senses and actuate its motor controls.  For example, turn right, turn left, move 
forward, move right, move left, move backward, grab, use, release.  The human 
should have grab right, grab left, use right, use left, release right, release 
left (based on which hand is used).  Senses should include a list of objects in 
view, with angle and distance, plus touch senses for front, right, left, and 
back, and also pleasure and pain.  The ground tiles should be either water 
(non-traversible but drinkable), stone, or dirt.  On dirt, grass, bushes, and 
trees may grow.  Deer eat the grass.  Humans eat the berries that grow on the 
bushes.  Deer may also eat the trees when they are very small but not once 
they've grown up.  Human may cut down trees and move the logs to create 
obstacles.  Bushes periodically regrow berries at different times for each bush. 
 When a plant grows to maximum size, it gradually spreads seeds to randomly 
nearby locations but may only grow where there is dirt.  Grass spreads only to 
adjacent spots but may only grow on dirt.  Animals walking over grass, small 
bushes, or small trees, can reverse their growth and destroy them, eventually.  
The wolf must eat the other animals for energy.  When energy is low, there is 
pain, and eventually death.  The humans may eat berries or deer.  Each species 
comes in two genders that, when fully grown, may mate to produce offspring.  The 
human's rate of having offspring is the slowest, followed by the worlf, and then 
the deer are the fastest.  There may also be rocks that humans can move.  
Movement reduces energy and faster or heavier movement reduces energy faster.  
Mating (for mature animals) induces pleasure.  Eating when energy is low also 
produces pleasure.  Drinking when hydration is low also produces pleasure and 
pain when hydration is too low.  Wolves kill by biting.  Only male deer may 
cause pain or kill be attacking.  Humans may use small rocks or sticks to kill. 
 
