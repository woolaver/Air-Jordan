%complete blown wing trade study

aircraft = aircraft();

numPropellers = [6, 8, 10, 12]; %ft
propellerDiameter = [4, 5, 6, 7]; %ft
propellerWeights = [13.8, 22.6, 38, 65]; %estimated weights for each diameter propeller in lbs

%studies
propellerGap = zeros([4,4]);
propulsionWeight = zeros([4,4]);
landingDistance = zeros([4,4]);
takeoffDistance = zeros([4,4]);

fus_width = aircraft.fuselage_width;
wingspan = aircraft.S/aircraft.wing_MAC;

for i = 1:4
    disp(i)
    for j = 1:4
        disp(j)
        propellerGap(i, j) = (wingspan - fus_width - (numPropellers(i)*propellerDiameter(j)))/(numPropellers(i));
        propulsionWeight(i, j) = numPropellers(i)*propellerWeights(j) + (10*33.7); %assuming same motor weight to match power output, technically weight would increase for anything other than 10 because gearboxs but oh well

        aircraft.num_propeller = numPropellers(i);
        aircraft.prop_diameter = propellerDiameter(j);

        [takeoff_distance, landing_distance] = BlownWingAnalysis(aircraft);

        takeoffDistance(i, j) = takeoff_distance;
        landingDistance(i, j) = landing_distance;
    end
end