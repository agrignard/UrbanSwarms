/***
* Name: TangibleUrbanSwarm
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TangibleUrbanSwarm

global {
	int port <- 9877;
	string url <- "localhost";	
	
	geometry shape<-rectangle(150,100);
	init {    
		create virtualAgent number: 1;
		create PhysicalAgent number: 1 {
		   do connect to: url protocol: "udp_server" port: port ;
		}
		
	} 
}

grid cell cell_width:50 cell_height:50{
	
	rgb color <-  #white;
} 


species PhysicalAgent skills:[network] {
	
	reflex fetch when:has_more_message() {	
		loop while:has_more_message()
		{
			message s <- fetch_message();
			list coordinates <- string(s.contents) split_with(";");
			location <- {int(coordinates[0]),int(coordinates[1])};
		}
	}
	
	aspect default {
		draw circle(5) color: #red border: #black; 
	}
}
	   
species virtualAgent skills: [moving] {
	aspect default {
		draw circle(5) color:#green border: #black;
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
			species virtualAgent aspect: default ;
			species PhysicalAgent;
		}
	}
}
