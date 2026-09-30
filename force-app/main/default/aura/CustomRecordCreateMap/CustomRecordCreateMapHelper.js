({
	initMap : function(component, event, helper) {
		var markersLayer = new L.LayerGroup();
        var markersLayerList = [];
        markersLayerList.push(markersLayer);

        map = L.map('map', { zoomControl: true, boxZoom: true, trackResize: true, doubleClickZoom: true })
                .setView([21.3049653, -157.8510732], 16);
        
        map.attributionControl.setPrefix('');
        L.tileLayer(
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', {
                attribution: 'Tiles © Esri'
            }).addTo(map);
        markersLayer.addTo(map);

        navigator.geolocation.getCurrentPosition(function(location) {
            map.setView([location.coords.latitude, location.coords.longitude], 16);
            var marker = component.get('v.marker');
            var newLatLng = new L.LatLng(location.coords.latitude, location.coords.longitude);
            marker.setLatLng(newLatLng); 
	        var sObj = component.get('v.sObj');
	        sObj[component.get('v.latitudeField')] = location.coords.latitude;
	        sObj[component.get('v.longitudeField')] = location.coords.longitude;
	        component.set('v.sObj', sObj);
        });
        
        var marker = new L.marker([21.3049653, -157.8510732], {draggable:'true'}).addTo(map);
        component.set('v.marker', marker);
        var sObj = component.get('v.sObj');
        sObj[component.get('v.latitudeField')] = 21.3049653;
        sObj[component.get('v.longitudeField')] = -157.8510732;
        component.set('v.sObj', sObj);
		marker.on('dragend', function(event){
			var marker2 = component.get('v.marker');
		    var position = marker2.getLatLng();
		    var sObj = component.get('v.sObj');
		    sObj[component.get('v.latitudeField')] = position.lat;
		    sObj[component.get('v.longitudeField')] = position.lng;
		    component.set('v.sObj', sObj);
		});
	}
})