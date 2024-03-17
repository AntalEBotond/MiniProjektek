import java.util.Scanner;

public class TobbszorEloforduloElemek {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("Add meg a tömb elemeit :");
        String input = scanner.nextLine();
        String[] elemekString = input.split(" ");
        int[] elemek = new int[elemekString.length];

        for (int i = 0; i < elemekString.length; i++) {
            elemek[i] = Integer.parseInt(elemekString[i]);
        }
        int[] elofordulasok = new int[101];
        for (int elem : elemek) {
            elofordulasok[elem]++;
        }
        System.out.println("A többször előforduló elemek:");
        for (int i = 0; i < elofordulasok.length; i++) {
            if (elofordulasok[i] > 1) {
                System.out.println(i + " (előfordulások száma: " + elofordulasok[i] + ")");
            }
        }
    }
}
