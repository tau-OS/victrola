project "victrola" {
    flatpak {
        manifest = "./com.fyralabs.Victrola.json"
    }
}

project "victrola-dev" {
    flatpak {
        manifest = "./com.fyralabs.Victrola.Devel.json"
    }
}