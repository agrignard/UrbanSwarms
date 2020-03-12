/***
* Name: TangibleUrbanSwarm
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TangibleUrbanSwarm

global {
	geometry shape<-rectangle(150,100);
	init {    
		create people number: 10;
		
	} 
}

grid cell cell_width:50 cell_height:50{
	
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
