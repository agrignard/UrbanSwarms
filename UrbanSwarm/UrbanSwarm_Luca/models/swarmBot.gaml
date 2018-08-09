/**
 *  theCity
 *  Author: alfeo
 *  Description: 
 * TODO: integration Dylan model, headless, stop collision avoidance and recharge. 
 */

model swarmBot
import "./../models/CityScope_main.gaml"

species dummy{
	
}

species controller{
 reflex performanceControl{
 	trashPerTime <- sum(list(trashBin) collect each.trash);
 	fullTrashBin <- length (trashBin where (each.trash>maxTrash)); 	
	save (string(seed) + "," + string(cycle) + "," + string(trashPerTime) + "," + string(fullTrashBin)) to: "./log/" + string(robotNum) + "-" + string(evaporation) + "-" + string(exploratoryRate) + "-" + string(carriableTrashAmount) + "-" + string(depositNum) + "perfHist" + string(randomID) + ".txt" type: "text" rewrite: false;	
	}
}

species pheromoneRoad {
	float pheromone;
	int lastUpdate;
	aspect base {
		draw shape + 1 + int(pheromone) color: #black;
	}
}

species deposit{
    int trash;
	int robots;
	aspect base {
			draw circle(25) color:#blue;		
		}
}

species trashBin {	
    float trash;
    bool decreaseTrashAmount;
    string type;
    rgb color;
    int group;
    
    reflex updateTrash{
    	
    	if(decreaseTrashAmount){
    		if (type='litter'){
	    		ask barrel closest_to self{
	    			self.total_trash<-myself.trash;
	    		}
	    	}else{
	    		ask amenityBin closest_to self{
	    			self.barrel_amount<-myself.trash;
	    		}
	    	}    
	    	decreaseTrashAmount<-false;	
    	}else{
	    	if (type='litter'){
	    		ask barrel closest_to self{
	    			myself.trash<-self.total_trash;
	    		}
	    	}else{
	    		ask amenityBin closest_to self{
	    			myself.trash<-self.barrel_amount;
	    		}
	    	}
    	}    	
    	
    }
	
	action update_color {
		int red_color <- int(0.0 + (255.0/float(maxTrash))*trash);
		int green_color <- int(255.0 - (255.0/float(maxTrash))*trash);
		color <- rgb(red_color,green_color,0);
	}
	
	aspect base {
		if(cycle<1){
			  draw circle(15) color:color;
			}else{
				do update_color;
				draw circle(15) color:color;	
				if(trash>maxTrash){
					draw triangle(10) color:#black;
				}else{
					if(trash>carriableTrashAmount){
						draw triangle(10) color:#yellow;
					}
				}		
			}
	}
}

species tagRFID {
	int id;
	bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	int lastUpdate;
	
	geometry towardDeposit;
	int distanceToDeposit;
	
	aspect base {
		draw circle(8+int(max(pheromones)/2)) color:#green;			
	}
}


species truck skills:[moving] {
	list<point> toClean;
	
	point target;
	path my_path; 
	point source;
	
	float speedDist;
	int timeToStart;
	int currentRoad;
	
	reflex searching when: (cycle > timeToStart){
	my_path <- self goto (on:roadNetwork, target:target, speed:speedDist, return_path: true);		
		
		if (target != location) { 
			list<trashBin> closeTrashBin <- trashBin at_distance 50;
	
			ask closeTrashBin{ //}with_max_of(each.trash){	
						self.trash <- 0;	
						self.decreaseTrashAmount <- true;	
			}						
		}	
		else{
			if(currentRoad<length(roadNetwork.vertices)-1){
				currentRoad <- currentRoad + 1;
				target <- point(roadNetwork.vertices[currentRoad]);//point(toClean[currentRoad]);
				source <- location;	
			}
			else{
			currentRoad <- currentRoad;
			}	
			write "tick " + cycle + " road " + currentRoad;		
		}
	}
	
	aspect base {
		draw circle(30) color: #black;
	}
}


species robot skills:[moving] {
	point target;
	path my_path; 
	point source;
	
	float pheromoneToDiffuse;
	float pheromoneMark; 
	
	int batteryLife;
	float speedDist; 
	
	int lastDistanceToDeposit;
	
	int timeStop; //TODO
	
	bool lowBattery;	
	bool carrying;
	bool stop; //TODO
	
	
	aspect base {
		draw circle(20) color: #cyan;
		if lowBattery{
			draw triangle(15) color: #purple;
		}
		if (carrying){
			draw square(15) color: #yellow;
		}
	}


	action updatePheromones{
		list<tagRFID>closeTag <- tagRFID at_distance 1;
		ask closeTag closest_to(self){
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
							self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
							
							if (self.pheromones[j]<0.001){
								self.pheromones[j] <- 0;
							}	
							
							if(myself.carrying){								
								if (self.pheromonesToward[j]=myself.source){
									self.pheromones[j] <- self.pheromones[j] + myself.pheromoneMark ;									
								}
																	
							}
							//Saturation
							if (self.pheromones[j]>50*singlePheromoneMark){
									self.pheromones[j] <- 50*singlePheromoneMark;
								}
				}
				// Update tagRFID and pheromoneToDiffuse
				self.lastUpdate <- cycle;				
				myself.pheromoneToDiffuse <- max(self.pheromones)*diffusion;
		}
		
		ask pheromoneRoad closest_to(self){	
			point p <- farthest_point_to (self , self.location);
			if (myself.location distance_to p < 1){			
				self.pheromone <- self.pheromone + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
								
				if (self.pheromone<0.01){
					self.pheromone <- 0.0;
				}	
								
				if(myself.carrying){
						self.pheromone <- self.pheromone + myself.pheromoneMark ;
				}	
				self.lastUpdate <- cycle;				
			}							
		}
	}
	
	reflex searching when: (!carrying and !lowBattery){		
		my_path <- self goto (on:roadNetwork, target:target, speed:speedDist, return_path: true);		
		
		if (target != location) { 
			//collision avoidance time
				do updatePheromones;
			//If there is enough battery and trash, carry it!
			list<trashBin> closeTrashBin <- trashBin at_distance 50;
			//ask closeTrashBin closest_to(self) {		
			ask closeTrashBin with_max_of(each.trash){		
				
				if (self.trash > carriableTrashAmount){
					if(myself.batteryLife > myself.lastDistanceToDeposit/myself.speedDist){
						self.trash <- self.trash - carriableTrashAmount;	
						self.decreaseTrashAmount<-true;
						myself.pheromoneMark <- (singlePheromoneMark * int(self.trash/carriableTrashAmount));		
						myself.carrying <- true;
					}
					else{
						myself.lowBattery <- true;
					}
				}	
			}
		}
		else{				
			ask tagRFID closest_to(self){
				myself.lastDistanceToDeposit <- self.distanceToDeposit;
				
				// If enough batteryLife follow the pheromone 
				if(myself.batteryLife < myself.lastDistanceToDeposit/myself.speedDist){ 
					myself.lowBattery <- true;
				}
				else{
				
					list<float> edgesPheromones <-self.pheromones;
					
					if(mean(edgesPheromones)=0){ 
						// No pheromones,choose a random direction
						myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
					}
					else{  
						// Follow strongest pheromone trail (with exploratoryRate Probbility if the last path has the strongest pheromone)					
						float maxPheromone <- max(edgesPheromones);	
						//*
						loop j from:0 to:(length(self.pheromonesToward)-1) {					
							if (maxPheromone = edgesPheromones[j]) and (myself.source = point(self.pheromonesToward[j])){
								edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
							}											
						}
						maxPheromone <- max(edgesPheromones);	

								
						// Follow strongest pheromone trail (with exploratoryRate Probability in any case)			
						loop j from:0 to:(length(self.pheromonesToward)-1) {			
							if (maxPheromone = edgesPheromones[j]){
								if flip(exploratoryRate){	
									myself.target <- point(self.pheromonesToward[j]);
									break;	
									}	
									else {
										myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
										break;
									}			
								}											
							}
						}				
					}
				}
				do updatePheromones;
				source <- location;
			}
	}

	reflex depositing when: (carrying or lowBattery){
		my_path <- self goto (on:roadNetwork, target:target, speed:speedDist, return_path: true);
		
		if (target != location) {
			//collision avoidance time
			do updatePheromones;
		}		
		else{				
			ask tagRFID closest_to(self) {
				// Update direction and distance from closest Deposit
				myself.target <- point(self.towardDeposit);
				myself.lastDistanceToDeposit <- self.distanceToDeposit;
				
				
			}
			do updatePheromones;
			source <- location;
			// Recover wandering status, delete pheromones over Deposits
			loop i from: 0 to: length(depositLocation) - 1 {
					if(location = point(roadNetwork.vertices[depositLocation[i]])){
						ask tagRFID closest_to(self){
							self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
						}
						
						ask deposit closest_to(self){
							if(myself.carrying){
								self.trash <- self.trash + carriableTrashAmount;
								myself.carrying <- false;
								myself.pheromoneMark <- 0.0;
							}
							if(myself.lowBattery){
								self.robots <- self.robots + 1;
								myself.lowBattery <- false;
								myself.batteryLife <- maxBatteryLife;
								// Add randomicity and diffusion when the battery is recharged
								myself.target <- point(one_of(deposit));
							}							
						}
					}
			}
		}
	}
	
}


/*
global {
	file shape_file_buildings <- file("../includes/City/volpe/Buildings.shp");
	file shape_file_roads <- file("../includes/City/volpe/Roads.shp");
	file shape_file_bounds <- file("../includes/City/volpe/Bounds.shp");
	file shape_file_amenities <- file("../includes/City/volpe/amenities.shp");
	file shape_file_trashBin <- file("../includes/City/volpe/DPW_LitterBarrels.shp");
	geometry shape <- envelope(shape_file_bounds);
	
	//----------------------------------------------------Variables-------------------------------------------------
	int robotNum <- 50;										
	float singlePheromoneMark <- 3.0;
	float evaporation <- 0.05;
	float diffusion <- 0.05;	
	int rechargingTime <- 0;
	int collisionAvoidanceTime <- 0;
	int additionalTrashBin <- 0;
	float maxTrash <- 20.0;
	int depositNum <- 4;
	
	graph roadNetwork;
	
	list<int> depositLocation;			

	
	init {
		
		// ----------------------------------------------The Buildings---------------------------------------------
		create building from: shape_file_buildings;			
		
		// -------------------------------------------The Restaurants---------------------------------------------	
		create restaurant from: shape_file_amenities;			
		
		// ----------------------------The Roads (459 and 462 are broken)-------------------------------------
		create pheromoneRoad from: shape_file_roads{
			pheromone <- 0.0;
		}		
		ask pheromoneRoad[459]{
			do die;
		}
		ask pheromoneRoad[462]{
			do die;
		}				
		
		// ---------------------------------------The Road Network----------------------------------------------
		roadNetwork <- as_edge_graph(pheromoneRoad) ;					
		
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);
		
		//-------------------------------------------Dummy-----------------------------------------------------
		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create dummy{
				location <-point(roadNetwork.vertices[i]); 
				}
			}
		
		// --------------------------------------------Trash Bins--------------------------------------------
		
		create trashBin from: shape_file_trashBin{ 					
			trashProduction <- (rnd(10) / 100000000) ;
			startProduction <- rnd(10000);
			endProduction <- startProduction + 1000;
			// Delete trashBin outside the area of interest 		
			float Xmax <- (list(dummy) max_of (each.location.x));
			float Ymax <- (list(dummy) max_of (each.location.y));
			float Xmin <- (list(dummy) min_of (each.location.x));
			float Ymin <- (list(dummy) min_of (each.location.y));
			if !((location.x between(Xmin,Xmax)) and (location.y between(Ymin,Ymax))){
				do die;
				}							
		}
		
	
		// -------------------------------------Location of the Deposits----------------------------------------
		//K-Means
		//Create a list of list containing for each trashBin agent a list composed of its x and y values
			list<list> instances <- trashBin collect ([each.location.x, each.location.y]);
			
			//from the previous list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
			list<list<int>> clusters_kmeans <- list<list<int>>(kmeans(instances, depositNum));
			
			//from clustered trashBin to centroids locations
			list<point> coordinatesCentroids <- [];
			loop cluster over: clusters_kmeans {
					list<point> coordinatesTrashBin <- [];
					rgb col <- rnd_color(255);
					loop TB over: cluster {
						add trashBin[TB].location to: coordinatesTrashBin; 
						ask trashBin[TB]{color <- col;}
					}
				add mean(coordinatesTrashBin) to: coordinatesCentroids;
			}
			
			//from centroids locations to closest intersection
			list<int> depositLocationKmeans;
			
			list<int> tmpDist;
			
			loop centroid from:0 to:length(coordinatesCentroids)-1 {
				tmpDist <- [];
				loop vertices from:0 to:length(roadNetwork.vertices)-1{
					add (point(roadNetwork.vertices[vertices]) distance_to coordinatesCentroids[centroid]) to: tmpDist;					
				}	
				loop vertices from:0 to: length(tmpDist)-1{
					if(min(tmpDist)=tmpDist[vertices]){
						add vertices to: depositLocationKmeans;
						break;
					}
				}	
			}
			
			// Final Outcome K-means
			depositLocation <- depositLocationKmeans;//[211,243,102];
		
		// ----------------------------------------------The Deposits---------------------------------------------
		
		loop i from: 0 to: length(depositLocation) - 1 {
			create deposit{
				location <- point(roadNetwork.vertices[depositLocation[i]]);
				trash <- 0;
				robots <- 0;
			}
		}
		
		// -------------------------------------------------The Robots --------------------------------------------
		create robot number:robotNum{						
			location <- point(one_of(roadNetwork.vertices)); 
			target <- location; 
			source <- location;
			carrying <- false;
			lowBattery <- false;
			stop <- false;
			timeStop <- 0;
			speedDist <- 1;
			pheromoneToDiffuse <- 0.0;
		}
		
		// ----------------------------------The RFIDs tag on each road intersection------------------------
		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create tagRFID{ 								
				id <- i;					
				location <- point(roadNetwork.vertices[i]); 
				pheromones <- [0.0,0.0,0.0,0.0,0.0];
				pheromonesToward <- neighbors_of(roadNetwork,roadNetwork.vertices[i]);  //to know what edge is related  to that amount of pheromone
				
				// Find the closest Deposit and set torwardDeposit and distanceToDeposit
				ask deposit closest_to self {
					myself.distanceToDeposit <- int(point(roadNetwork.vertices[i]) distance_to self.location);
					loop y from: 0 to: length(depositLocation) - 1 {
						if (point(roadNetwork.vertices[depositLocation[y]]) = self.location){
							myself.towardDeposit <- point(roadNetwork.vertices[allPairs[depositLocation[y],i]]);
							if (myself.towardDeposit=point(roadNetwork.vertices[i])){
								myself.towardDeposit <- point(roadNetwork.vertices[depositLocation[y]]);
							}
							break;
						}				
					}					
				}				
				type <- 'roadIntersection';				
				loop y from: 0 to: length(depositLocation) - 1 {
					if (i=depositLocation[y]){
						type <- 'Deposit&roadIntersection';
					}
				}	
								
			}
		}
		
		ask dummy {do die;}
	}	
}


experiment selfOrganizedGarbageCollection type: gui {
	parameter "NumberOfRobots" var: robotNum min: 1 max: 100 step: 2;
	parameter "NumberOfDeposits" var: depositNum min: 1 max: 5 step: 1;
	parameter "AdditionalTrashBin" var: additionalTrashBin min: 0 max: 100 step: 2;
	parameter "PheromoneMarkIntensity" var: singlePheromoneMark min: 0.1 max: 10.0 step: 0.1;
	parameter "EvaporatioRate" var: evaporation min: 0.001 max: 1.0 step: 0.001;
	parameter "DiffusionRate" var: diffusion min: 0.001 max: 1.0 step: 0.001;
	parameter "rechargingTime" var: rechargingTime min: 0 max: 10 step: 1;
	parameter "collisionAvoidanceTime" var: collisionAvoidanceTime min: 0 max: 10 step: 1;
	parameter "maxTrashPerBin" var: maxTrash min: 1.0 max: 50.0 step: 1.0;
	
	output {
 
		display system_responsiveness{
			chart "Cleaning demand/response"{
				data "Robot carrying" value: length (robot where (each.carrying=true)) color:#blue;
				
				data "Trash Amount" value: sum(list(trashBin) collect each.trash) color:#red;
				
				data "Full Trash Bins" value: length (trashBin where (each.trash>maxTrash)) color:#purple;

				data "Pheromone Amount" value: sum(list(tagRFID) collect mean(each.pheromones)) color:#green;
			}
		}
		
		display deposits{
			chart "Deposits usage"{
				data "Robot visiting" value: sum(list(deposit) collect each.trash) color:#blue;
				
				data "Robot depositing" value: sum(list(deposit) collect each.robots) color:#red;				

			}
		}
		
		display city_display type:opengl {
			species building aspect: base ;
			species restaurant aspect: base;
			species pheromoneRoad aspect: base ;
			species trashBin aspect: base ;
			species tagRFID aspect: base ;
			species robot aspect: base ;
			species deposit aspect: base;
		}

	}
}

*/



