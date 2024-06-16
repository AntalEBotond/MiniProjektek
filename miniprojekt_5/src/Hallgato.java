import java.util.ArrayList;

public class Hallgato {
    private static int counter = 0;
    private final int ID;
    private final String vezeteknev;
    private final String keresztnev;
    private final ArrayList<Jegy> jegyek;

    public Hallgato(String vezeteknev, String keresztnev) {
        this.ID = ++counter;
        this.vezeteknev = vezeteknev;
        this.keresztnev = keresztnev;
        this.jegyek = new ArrayList<>();
    }

    public int getID() {
        return ID;
    }

    public String getVezeteknev() {
        return vezeteknev;
    }

    public String getKeresztnev() {
        return keresztnev;
    }

    public void ujBejegyzes(Jegy jegy) {
        jegyek.add(jegy);
    }

    public Double tantargyAtlag(String tantargy) {
        int sum = 0;
        int count = 0;
        for (Jegy jegy : jegyek) {
            if (jegy.getTantargy().equals(tantargy)) {
                sum += jegy.getJegy();
                count++;
            }
        }
        return count == 0 ? null : (double) sum / count;
    }

    public ArrayList<String> getTantargyak() {
        ArrayList<String> tantargyak = new ArrayList<>();
        for (Jegy jegy : jegyek) {
            if (!tantargyak.contains(jegy.getTantargy())) {
                tantargyak.add(jegy.getTantargy());
            }
        }
        return tantargyak;
    }

    public void listazas() {
        System.out.println(vezeteknev + " " + keresztnev);
        for (String tantargy : getTantargyak()) {
            System.out.println(tantargy + ": " + tantargyAtlag(tantargy));
        }
    }
}
