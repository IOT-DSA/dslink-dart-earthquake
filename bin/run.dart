import "package:dslink/client.dart";
import "package:dslink/responder.dart";
import "package:http/http.dart" as http;

import "dart:async";
import "dart:convert";

const String DAY_URL = "http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";

http.Client client = new http.Client();
SimpleNode rootNode;
LinkProvider link;
Timer timer;

main(List<String> args) async {
  link = new LinkProvider(args, "Earthquakes-", defaultNodes: {
    "Get_All": {
      r"$name": "Get All",
      r"$is": "getAll",
      r"$invokable": "read",
      r"$result": "table",
      r"$columns": [
        {
          "name": "id",
          "type": "string"
        },
        {
          "name": "title",
          "type": "string"
        },
        {
          "name": "place",
          "type": "string"
        },
        {
          "name": "alert",
          "type": "string"
        },
        {
          "name": "magnitude",
          "type": "num"
        },
        {
          "name": "latitude",
          "type": "num"
        },
        {
          "name": "longitude",
          "type": "num"
        },
        {
          "name": "depth",
          "type": "num"
        }
      ]
    }
  }, profiles: {
    "getAll": (String path) => new GetAllActionNode(path)
  });

  link.connect();
  rootNode = link["/"];

  timer = new Timer.periodic(new Duration(seconds: 15), (_) async {
    await update();
  });

  await update();
}

update() async {
  var json = await getEarthquakeInformation();
  if (json == null) {
    return;
  }
  var features = json["features"];
  ids = features.map((it) => it["id"]).toList();
  var toRemove = rootNode.children.keys.where((it) => !ids.contains(it) && it != "Get_All").toList();
  for (var x in toRemove) {
    rootNode.removeChild(x);
  }

  for (Map<String, dynamic> feature in features) {
    Map<String, dynamic> props = feature["properties"];
    String id = feature["id"];

    if (!rootNode.children.containsKey(id)) {
      link.addNode("/${id}", createEarthquakeInitializer());
    }

    SimpleNode node = link[id];
    v(String name, dynamic value) {
      link.updateValue("/${node.path}/${name}", value);
    }

    var coords = feature["geometry"]["coordinates"];

    v("Title", props["title"]);
    v("Place", props["place"]);
    v("Timestamp", new DateTime.fromMillisecondsSinceEpoch(props["time"]).toString());
    v("Updated", new DateTime.fromMillisecondsSinceEpoch(props["updated"]).toString());
    v("Type", props["type"]);
    v("Alert", props["alert"] == null ? "unknown" : props["alert"]);
    v("Magnitude", props["mag"]);
    v("Latitude", coords[1]);
    v("Longitude", coords[0]);
    v("Depth", coords[2]);
    v("Felt", props["felt"] == null ? 0 : props["felt"]);
    v("RMS", props["rms"]);
    v("Magnitude_Type", props["magType"]);
    v("Significance", props["sig"]);
    v("Tsunami", props["tsunami"] == 1);
    v("URL", props["url"]);
    v("Status", props["status"]);
    v("Timezone", props["tz"]);
  }
}

Map<String, dynamic> createEarthquakeInitializer() => {
  "Title": {
    r"$type": "string"
  },
  "Place": {
    r"$type": "string"
  },
  "Timestamp": {
    r"$type": "string"
  },
  "Updated": {
    r"$type": "string"
  },
  "Type": {
    r"$type": "string"
  },
  "Alert": {
    r"$type": "enum[unknown,green,yellow,orange,red]"
  },
  "Magnitude": {
    r"$type": "num"
  },
  "Latitude": {
    r"$type": "num"
  },
  "Longitude": {
    r"$type": "num"
  },
  "Depth": {
    r"$type": "num"
  },
  "Felt": {
    r"$type": "num"
  },
  "RMS": {
    r"$type": "num"
  },
  "Magnitude_Type": {
    r"$name": "Magnitude Type",
    r"$type": "string"
  },
  "Maximum_Intensity": {
    r"$name": "Maximum Intensity",
    r"$type": "num"
  },
  "Significance": {
    r"$type": "int"
  },
  "Tsunami": {
    r"$name": "Is Tsunami",
    r"$type": "bool"
  },
  "URL": {
    r"$type": "string"
  },
  "Status": {
    r"$type": "string"
  },
  "Timezone": {
    r"$type": "int"
  }
};

List<String> ids = [];

class GetAllActionNode extends SimpleNode {
  GetAllActionNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    var rows = [];

    for (var id in ids) {
      SimpleNode node = link.provider.getNode("/${id}");
      var map = {};
      v(String name) {
        return (node.getChild(name) as SimpleNode).lastValueUpdate.value;
      }
      map["id"] = node.path.split("/").last;
      map["title"] = v("Title");
      map["place"] = v("Place");
      map["alert"] = v("Alert");
      map["magnitude"] = v("Magnitude");
      map["latitude"] = v("Latitude");
      map["longitude"] = v("Longitude");
      map["depth"] = v("Depth");
      rows.add(map);
    }
    return rows;
  }
}

getEarthquakeInformation() async {
  try {
    http.Response response = await http.get(DAY_URL);
    if (response.statusCode != 200) {
      return null;
    }
    return JSON.decode(response.body);
  } catch (e) {
    return null;
  }
}
