/**
 *  theCity
 *  Author: alfeo
 *  Description: Model containing 
 * TODO: integration Dylan model, headless, stop collision avoidance and recharge. 
 */

model swarmBot
import "./../models/UrbanSwarm_main.gaml"

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

