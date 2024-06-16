import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        Hallgato hallgato = new Hallgato("Nagy", "Elemer");
        hallgato.ujBejegyzes(new Jegy("Matek", 10));
        hallgato.ujBejegyzes(new Jegy("Matek", 8));
        hallgato.ujBejegyzes(new Jegy("Roman", 7));
        hallgato.ujBejegyzes(new Jegy("Roman", 8));
        hallgato.ujBejegyzes(new Jegy("Magyar", 9));
        hallgato.listazas();

        Naplo naplo = new Naplo("hallgatok.csv");
        naplo.listazNevek();

        BufferedReader br = new BufferedReader(new FileReader("jegyek.txt"));
        String line;
        while ((line = br.readLine()) != null) {
            String[] parts = line.split(",");
            int ID = Integer.parseInt(parts[0].trim());
            String tantargy = parts[1].trim();
            int jegy = Integer.parseInt(parts[2].trim());
            naplo.ujJegy(ID, new Jegy(tantargy, jegy));
        }
        br.close();

        naplo.listazHallgatoiAdatok();
    }
}
