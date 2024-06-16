import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

public class Naplo {
    private final ArrayList<Hallgato> hallgatok;

    public Naplo(String file) throws IOException {
        hallgatok = new ArrayList<>();
        BufferedReader br = new BufferedReader(new FileReader(file));
        String line;
        while ((line = br.readLine()) != null) {
            String[] parts = line.split(",");
            Hallgato hallgato = new Hallgato(parts[0].trim(), parts[1].trim());
            hallgatok.add(hallgato);
        }
        br.close();
    }

    public void listazNevek() {
        for (Hallgato hallgato : hallgatok) {
            System.out.println(hallgato.getID() + ". " + hallgato.getVezeteknev() + " " + hallgato.getKeresztnev());
        }
    }

    public void ujJegy(int ID, Jegy jegy) {
        for (Hallgato hallgato : hallgatok) {
            if (hallgato.getID() == ID) {
                hallgato.ujBejegyzes(jegy);
                break;
            }
        }
    }

    public void listazHallgatoiAdatok() {
        for (Hallgato hallgato : hallgatok) {
            hallgato.listazas();
        }
    }
}
