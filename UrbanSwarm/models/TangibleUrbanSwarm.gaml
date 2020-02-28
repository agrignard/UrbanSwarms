/***
* Name: TangibleUrbanSwarm
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TangibleUrbanSwarm

global {
	init {    
		create people number: 10;
	} 
}

grid cell width: 5 height: 5  {
	rgb color <-  #white;
} 
	   
species people skills: [moving] {
	aspect default {
		draw circle(1) color: #black;
	}
	reflex move{
		do wander;
	}
}

experiment urbanGrid type: gui {
	float minimum_cycle_duration<-0.05;
	output {
		display objects_display type:opengl{
			grid cell lines: #black;
			species people aspect: default ;
		}
	}
}
